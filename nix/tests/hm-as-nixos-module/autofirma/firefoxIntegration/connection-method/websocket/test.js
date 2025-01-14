// JavaScript implementation for TestAutoFirma using provided signing services

(function() {
    function initializeMiniApplet(storageUrl, retrieverUrl) {
        console.log(`Initializing MiniApplet with ${storageUrl} and ${retrieverUrl}`);
        MiniApplet.cargarAppAfirma(storageUrl);
    }

    function generateSignature(data, onSuccess, onError) {
        try {
            MiniApplet.sign(data, "SHA256withRSA", "CAdES", "headless=true", onSuccess, onError);
        } catch (error) {
            onError("Exception", error.message);
        }
    }

    function sendResultToServer(message) {
        const formData = new FormData();
        formData.append("test_output", message);

        fetch("/test.php", {
            method: "POST",
            body: formData
        }).then(response => {
            if (response.ok) {
                console.log("Result sent successfully.");
            } else {
                console.error("Failed to send result to server.");
            }
        }).catch(error => {
            console.error("Error sending result to server:", error);
        });
    }

    function handleSignatureResult(message) {
        console.log(`Signature Successful: ${message}`);
        sendResultToServer(`Signature Successful: ${message}`);
    }

    function handleError(errorType, errorMessage) {
        console.error(`Error (${errorType}): ${errorMessage}`);
        sendResultToServer(`Error (${errorType}): ${errorMessage}`);
    }

    function startSigningProcess() {
        const storageUrl = '/afirma-signature-storage';
        const retrieverUrl = '/afirma-signature-retriever';
        const dataToSign = btoa(document.documentElement.outerHTML);

        initializeMiniApplet(storageUrl, retrieverUrl);

        generateSignature(
            dataToSign,
            handleSignatureResult,
            handleError
        );
    }

    // Automatically start the signing process on page load
    window.addEventListener('DOMContentLoaded', startSigningProcess);
})();
