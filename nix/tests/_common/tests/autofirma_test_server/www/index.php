<?php

// Define the path for storing POST data.
$outputFile = "/tmp/test_output.txt";

// Handle GET request.
if ($_SERVER['REQUEST_METHOD'] === 'GET') {

    // Prepare the HTML content.
    echo "<!DOCTYPE html>\n";
    echo "<html lang=\"en\">\n";
    echo "<head>\n";
    echo "    <meta charset=\"UTF-8\">\n";
    echo "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n";
    echo "    <title>Test Page</title>\n";
    echo "</head>\n";
    echo "<body>\n";

    // Always load autoscript.js.
    echo "    <script src=\"js/autoscript.js\"></script>\n";
    echo "    <script src=\"test.js\"></script>\n";

    echo "</body>\n";
    echo "</html>\n";

    exit;
}

// Handle POST request.
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get the "test_output" parameter from the form data.
    $testOutput = isset($_POST['test_output']) ? $_POST['test_output'] : '';

    // Write the data to the output file.
    if (file_put_contents($outputFile, $testOutput . "\n") === false) {
        echo "Failed to write to $testFile";
        exit;
    }

    // Respond to the client.
    echo "Data has been saved successfully.";
    exit;
}

// Handle other request methods.
http_response_code(405); // Method Not Allowed
header("Allow: GET, POST");
echo "Unsupported request method.";
exit;
