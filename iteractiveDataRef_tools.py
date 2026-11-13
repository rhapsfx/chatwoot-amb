
def download_message(payload):
    # Load configurations
    CONFIG = load_config()

    message_interactive = payload.get("interactiveDataRef")
    BIZ_ID = payload.get("destinationId")
    if message_interactive:
        bid = message_interactive.get("bid")

        #requestGet variables
        hex_encoded_signature = message_interactive.get("signature").upper()
        mmcs_url = message_interactive.get("url")
        mmcs_owner = message_interactive.get("owner")
        file_size = message_interactive.get("size")
        decryption_key = message_interactive.get("key").upper()

        # send request.get with hex_encoded_signature to retrieve encrypted data
        decrypted_attachment_data = decryptRequest(hex_encoded_signature, mmcs_url, mmcs_owner, file_size, decryption_key, BIZ_ID)

        decode_headers = {
            "Authorization": "Bearer %s" % get_jwt_token(),
            "source-id": BIZ_ID,
            "accept": "*/*",
            "accept-encoding": "gzip, deflate",
            "bid": bid
        }
        r = requests.post("%s/decodePayload" % CONFIG["amb_server"],
                          headers=decode_headers,
                          data=decrypted_attachment_data,
                          timeout=10)

        newj = json.loads(r.text)

        try:
            del newj["images"]  # <-- Remove the image bitmaps to make the payload managable
        except KeyError as ekey:
            print("Images removal error")
            print(ekey)
            pass

        return newj


def decryptRequest(hex_encoded_signature, mmcs_url, mmcs_owner, file_size, decryption_key, business_id):
    # Load configurations
    CONFIG = load_config()

    signature = base64.b16decode(hex_encoded_signature)
    base64_encoded_signature = base64.b64encode(signature)

    predownload_headers = {
        "authorization": "Bearer %s" % get_jwt_token(),
        "source-id": business_id,
        "mmcs-url": mmcs_url,
        "mmcs-signature": base64_encoded_signature,
        "mmcs-owner": mmcs_owner
    }

    r = requests.get("%s/preDownload" % CONFIG["amb_server"], headers=predownload_headers,
                         timeout=10)

    download_url = json.loads(r.content).get("download-url")

    # download the attachment data with GET request
    encrypted_attachment_data = requests.get(download_url).content

    # compare download size with expected file size
    #if len(encrypted_attachment_data) != file_size:
    #    raise Exception("Data downloaded not of expected size! Check preDownload step.")

    # decrypted the downloaded data
    decrypted_attachment_data = decrypt(encrypted_attachment_data, decryption_key)
    return decrypted_attachment_data
