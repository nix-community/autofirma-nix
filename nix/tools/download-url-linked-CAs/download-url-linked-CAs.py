#!/usr/bin/env python3

from concurrent.futures import ThreadPoolExecutor
from functools import partial
from urllib.parse import urljoin
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
import requests


def get_urls(url, driver):
    driver.get(url)
    soup = BeautifulSoup(driver.page_source, 'html.parser')
    return [urljoin(url, a['href']) for a in soup.find_all('a', href=re.compile(r'\.(crt|cert?|pem)$'))]


def is_self_signed(path):
    result = subprocess.run(['openssl', 'x509', '-in', path, '-noout', '-issuer', '-subject'], 
                            capture_output=True, text=True)
    try:
        issuer_subject = set(line.split('=', 1)[1] for line in result.stdout.strip().split('\n'))
    except IndexError:
        print(f"Error processing {path}: {result.stderr}", file=sys.stderr)
        return None
    return len(issuer_subject) == 1


def get_sri_hash(path):
    flat_hash = subprocess.run(['nix-hash', '--type', 'sha256', '--flat', path], 
                               capture_output=True, text=True).stdout.strip()
    return subprocess.run(['nix-hash', '--type', 'sha256', '--to-sri', flat_hash], 
                          capture_output=True, text=True).stdout.strip()



def process_cert_url(cert_url, user_agent):
    """Download one .crt/.pem link, check if it's self-signed, and return SRI hash if so."""
    print(f"Processing {cert_url}", file=sys.stderr)

    # Get extension from the URL
    ext = os.path.splitext(cert_url)[1].lower()

    with tempfile.NamedTemporaryFile(suffix=ext) as tmp:
        r = requests.get(cert_url, headers={'User-Agent': user_agent} if user_agent else None)
        tmp.write(r.content)
        tmp.flush()

        path = tmp.name

        if is_self_signed(path):
            hash_value = get_sri_hash(path)
            return {
                'url': cert_url,
                'hash': hash_value
            }

        return None  # Not self-signed


def escape_curl_opts(opts):
    """Allow escaping dashes in curl options"""
    return [re.sub(r'\\-', '-', opt) for opt in opts]


def do_scrape(url, headless, max_workers, user_agent, curl_opts):
    """
    Perform the scraping for the given parameters.
    Returns a list of certificate dicts.
    """
    options = Options()
    if headless:
        # Use the newer headless argument for Chrome if available
        options.add_argument('--headless=new')
    options.add_argument('--disable-application-cache')
    options.add_argument(f'--user-agent={user_agent}')

    service = Service(os.environ.get('CHROMEDRIVER_PATH'))  # or None
    driver = webdriver.Chrome(service=service, options=options)

    # Turn off caching
    driver.execute_cdp_cmd('Network.setCacheDisabled', {'cacheDisabled': True})

    results = []
    try:
        found_links = get_urls(url, driver)
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            process_func = partial(process_cert_url, user_agent=user_agent)
            # filter(None, ...) to drop any that returned None
            results = list(filter(None, executor.map(process_func, found_links)))
    finally:
        driver.quit()

    # Deduplicate by turning each dict into a frozenset of (k,v)
    unique_results = [dict(t) for t in set(frozenset(d.items()) for d in results)]

    # If we had extra curl options, add them to each item
    if curl_opts:
        # Possibly adjust them first:
        curl_opts = escape_curl_opts(curl_opts)
        for item in unique_results:
            item['curlOptsList'] = curl_opts

    return unique_results


def main(cli_args):
    """
    Always read exactly one JSON object from stdin.
    That JSON must contain at least "url". The rest of the fields can override
    or supplement the script's command-line defaults for dev usage.
    """
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: Could not decode JSON from stdin: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(data, dict):
        print("Error: Expected exactly one JSON object on stdin (not an array).", file=sys.stderr)
        sys.exit(1)

    # "url" is mandatory
    if 'url' not in data:
        print("Error: JSON object must include a 'url' field.", file=sys.stderr)
        sys.exit(1)

    # Fields in JSON override the command-line values:
    url = data['url']
    headless = data.get('headless', cli_args.headless)
    max_workers = data.get('max_workers', cli_args.max_workers)
    user_agent = data.get('user_agent', cli_args.user_agent)
    curl_opts = data.get('curlOptsList', cli_args.extra_curl_opts)

    # "cif" is optional, but we can store it if present:
    cif = data.get('cif')

    # Scrape certificates:
    results = do_scrape(
        url=url,
        headless=headless,
        max_workers=max_workers,
        user_agent=user_agent,
        curl_opts=curl_opts
    )

    # If "cif" was provided, attach it to each result so the user can identify them:
    if cif is not None:
        for r in results:
            r['cif'] = cif

    # Print final JSON array
    print(json.dumps(results, indent=2, sort_keys=True))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Download and hash certificates linked from a URL (JSON from STDIN).'
    )
    # We no longer accept a positional URL argument; the URL now *must* come from JSON
    parser.add_argument('--headless', action=argparse.BooleanOptionalAction,
                        help='Run Chrome in headless mode', default=True)
    parser.add_argument('-n', '--max-workers', type=int, default=8,
                        help='Maximum number of threads to use.')
    parser.add_argument('--user-agent', default='Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0',
                        help='User agent string to use.')
    parser.add_argument('--extra-curl-opts', action='append',
                        help='Extra curl options to include in curlOptsList')

    args = parser.parse_args()
    main(args)
