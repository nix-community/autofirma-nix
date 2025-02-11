#!/usr/bin/env python3

from concurrent.futures import ThreadPoolExecutor
from _ctypes import PyObj_FromPtr
from functools import partial
from urllib.parse import urljoin
import argparse
import json
import os
import random
import re
import subprocess
import sys
import tempfile
import time

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service


class NoIndent(object):
    """ Value wrapper. """
    def __init__(self, value):
        self.value = value


class MyEncoder(json.JSONEncoder):
    FORMAT_SPEC = '@@{}@@'
    regex = re.compile(FORMAT_SPEC.format(r'(\d+)'))

    def __init__(self, **kwargs):
        # Save copy of any keyword argument values needed for use here.
        self.__sort_keys = kwargs.get('sort_keys', None)
        super(MyEncoder, self).__init__(**kwargs)

    def default(self, obj):
        return (self.FORMAT_SPEC.format(id(obj)) if isinstance(obj, NoIndent)
                else super(MyEncoder, self).default(obj))

    def encode(self, obj):
        format_spec = self.FORMAT_SPEC  # Local var to expedite access.
        json_repr = super(MyEncoder, self).encode(obj)  # Default JSON.

        # Replace any marked-up object ids in the JSON repr with the
        # value returned from the json.dumps() of the corresponding
        # wrapped Python object.
        for match in self.regex.finditer(json_repr):
            # see https://stackoverflow.com/a/15012814/355230
            id = int(match.group(1))
            no_indent = PyObj_FromPtr(id)
            json_obj_repr = json.dumps(no_indent.value, sort_keys=self.__sort_keys)

            # Replace the matched id string with json formatted representation
            # of the corresponding Python object.
            json_repr = json_repr.replace(
                            '"{}"'.format(format_spec.format(id)), json_obj_repr)

        return json_repr


def get_urls(url, driver):
    driver.get(url)
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(driver.page_source, 'html.parser')
    return [urljoin(url, a['href']) for a in soup.find_all('a', href=re.compile(r'\.(crt|cert?|pem)$'))]


def is_self_signed(path):
    """
    Check if the X.509 certificate is self-signed by comparing
    its subject and issuer lines. If they match, it's self-signed.
    """
    result = subprocess.run(
        ['openssl', 'x509', '-in', path, '-noout', '-issuer', '-subject'], 
        capture_output=True, text=True
    )
    try:
        issuer_subject = set(line.split('=', 1)[1] for line in result.stdout.strip().split('\n'))
    except IndexError:
        print(f"Error processing {path}: {result.stderr}", file=sys.stderr)
        return None
    return len(issuer_subject) == 1


def get_sri_hash(path):
    """
    Use nix-hash to compute a sha256-based SRI hash of the file at 'path'.
    """
    flat_hash = subprocess.run(
        ['nix-hash', '--type', 'sha256', '--flat', path], 
        capture_output=True, text=True
    ).stdout.strip()

    sri_hash = subprocess.run(
        ['nix-hash', '--type', 'sha256', '--to-sri', flat_hash], 
        capture_output=True, text=True
    ).stdout.strip()

    return sri_hash


def escape_curl_opts(opts):
    """Allow escaping dashes in curl options (as used in the original script)."""
    return [re.sub(r'\\-', '-', opt) for opt in opts]


def curl_download(url, dest_path, user_agent=None, extra_opts=None):
    """
    Download 'url' to 'dest_path' using curl. 
    Respects 'user_agent' and any extra options in 'extra_opts'.
    Equivalent to the original requests.get(..., verify=False),
    we also add '-k' to ignore certificate issues.
    """
    cmd = [
        'curl',
        '-sS',                     # silent + show errors
        '-L',                      # follow redirects (similar to requests default)
        '-k',                      # ignore cert errors (requests verify=False)
        '--connect-timeout', '10', # Timeout for the TCP connection phase
        '--max-time', '30',        # Maximum time for the entire request
        '--retry', '10',           # Number of retries
        '--retry-delay', '5',      # Seconds to wait between retries
        '--retry-all-errors',      # Retry on both transient & some non-transient errors
        '-o', dest_path
    ]
    if user_agent:
        cmd += ['-A', user_agent]

    if extra_opts:
        cmd += extra_opts

    cmd.append(url)

    # Run the curl command and capture any errors
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        # Raise or handle errors as you see fit. Here we just print to stderr.
        print(f"curl failed for {url}:\n{result.stderr}", file=sys.stderr)
        return False

    return True


def process_cert_url(cert_url, user_agent, curl_opts=None):
    """
    Download one .crt/.pem link, check if it's self-signed, 
    and return SRI hash dict if so, else None.
    """
    print(f"Processing {cert_url}", file=sys.stderr)

    # Be nice to the server 5 to 10 seconds delay
    time.sleep(random.randint(5, 10))

    # Get extension from the URL
    ext = os.path.splitext(cert_url)[1].lower()

    with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
        # Use curl to fetch the certificate
        success = curl_download(
            url=cert_url,
            dest_path=tmp.name,
            user_agent=user_agent,
            extra_opts=curl_opts
        )
        
        if not success:
            return None
        
        path = tmp.name

        if is_self_signed(path):
            hash_value = get_sri_hash(path)
            return {
                'url': cert_url,
                'hash': hash_value
            }

        return None  # Not self-signed


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

    # Turn off caching in Chrome
    driver.execute_cdp_cmd('Network.setCacheDisabled', {'cacheDisabled': True})

    results = []
    try:
        found_links = get_urls(url, driver)

        # Filter out duplicates in found_links, if desired:
        # found_links = list(set(found_links))

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            process_func = partial(process_cert_url, user_agent=user_agent, curl_opts=curl_opts)
            # filter(None, ...) to drop any that returned None
            results = list(filter(None, executor.map(process_func, found_links)))
    finally:
        driver.quit()

    # Deduplicate by turning each dict into a frozenset of (k,v)
    unique_results = [dict(t) for t in set(frozenset(d.items()) for d in results)]

    # If we had extra curl options, store them in each item
    if curl_opts:
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

    # Possibly escape them first (if you want the same behavior as original):
    if curl_opts:
        curl_opts = escape_curl_opts(curl_opts)

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

    if not results:
        print("No self-signed certificates found. ABORTING RUN!", file=sys.stderr)
        sys.exit(1)

    # Print final JSON array
    sorted_result = sorted([NoIndent(r) for r in  results], key=lambda r: r.value["url"])
    print(json.dumps(sorted_result, cls=MyEncoder, indent=2, sort_keys=True))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Download and hash certificates linked from a URL (JSON from STDIN).'
    )
    # We no longer accept a positional URL argument; the URL now *must* come from JSON
    parser.add_argument('--headless', action=argparse.BooleanOptionalAction,
                        help='Run Chrome in headless mode', default=True)
    parser.add_argument('-n', '--max-workers', type=int, default=8,
                        help='Maximum number of threads to use.')
    parser.add_argument('--user-agent',
                        default='Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0',
                        help='User agent string to use.')
    parser.add_argument('--extra-curl-opts', action='append',
                        help='Extra curl options to include in curlOptsList')

    args = parser.parse_args()
    main(args)
