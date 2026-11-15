class AppleMessagesForBusiness::InteractiveDataReferenceService
  include ::FileTypeHelper

  MSP_GATEWAY_URL = 'https://mspgw.push.apple.com/v1'.freeze

  def initialize(idr_data:, channel:)
    @idr_data = idr_data
    @channel = channel
  end

  def retrieve_and_decrypt
    # Rails.logger.info '[AMB IDR] Starting Interactive Data Reference processing'
    # Rails.logger.info "[AMB IDR] IDR Data: #{@idr_data.inspect}"

    validate_idr_data!

    # Step 1: Download the encrypted data from the IDR URL
    encrypted_data = download_encrypted_data

    # Step 2: Decrypt and decode the data using Apple's /decodePayload endpoint
    decrypt_data(encrypted_data)

    # Rails.logger.info '[AMB IDR] Successfully processed Interactive Data Reference'
    # Rails.logger.info "[AMB IDR] Final data keys: #{interactive_data.keys.inspect}"

  rescue StandardError => e
    Rails.logger.error "[AMB IDR] Failed to process Interactive Data Reference: #{e.message}"
    Rails.logger.error "[AMB IDR] Backtrace: #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def validate_idr_data!
    required_fields = %w[bid owner url size signature]
    missing_fields = required_fields.reject { |field| @idr_data[field].present? }

    raise ArgumentError, "Missing required IDR fields: #{missing_fields.join(', ')}" if missing_fields.any?

    # Check for decryption key (either 'key' or 'dataRefSig')
    return if @idr_data['key'].present? || @idr_data['dataRefSig'].present?

    raise ArgumentError, 'Missing decryption key: neither "key" nor "dataRefSig" found'

    # Rails.logger.info '[AMB IDR] IDR data validation passed'
  end

  def download_encrypted_data
    # Rails.logger.info '[AMB IDR] Starting IDR download process'
    # Rails.logger.info "[AMB IDR] Original iCloud URL: #{@idr_data['url']}"

    # Step 1: Call /preDownload to get temporary download URL
    download_url = call_pre_download

    # Step 2: Download from the temporary URL (no special headers needed)
    encrypted_data = download_from_url(download_url)

    # Verify the size matches the expected size
    expected_size = @idr_data['size'].to_i
    if encrypted_data.bytesize != expected_size
      Rails.logger.warn "[AMB IDR] Size mismatch: expected #{expected_size}, got #{encrypted_data.bytesize}"
      # Don't fail on size mismatch, just warn - content might still be valid
    end

    encrypted_data
  end

  def call_pre_download
    # Rails.logger.info '[AMB IDR] Calling /preDownload to get temporary URL'

    # Convert hex signature to base64 as required by Apple MSP
    # Python reference: signature = base64.b16decode(hex_encoded_signature)
    #                   base64_encoded_signature = base64.b64encode(signature)
    hex_signature = @idr_data['signature']
    base64_signature = (@idr_data['signature-base64'].presence || Base64.strict_encode64([hex_signature].pack('H*')))

    # Prepare headers for /preDownload request (GET, not POST!)
    # Python reference uses lowercase header names (line 174-179 in reference)
    headers = {
      'authorization' => "Bearer #{@channel.generate_jwt_token}",
      'source-id' => @channel.business_id, # Use business_id for source-id
      'mmcs-url' => @idr_data['url'],
      'mmcs-signature' => base64_signature,
      'mmcs-owner' => @idr_data['owner']
    }

    # Rails.logger.info "[AMB IDR] PreDownload request headers: #{headers.except('authorization').inspect}"

    # Use GET, not POST (per Python reference implementation)
    response = HTTParty.get(
      "#{MSP_GATEWAY_URL}/preDownload",
      headers: headers,
      timeout: 30
    )

    unless response.success?
      Rails.logger.error "[AMB IDR] PreDownload failed: #{response.code} #{response.message}"
      Rails.logger.error "[AMB IDR] PreDownload response body: #{response.body}"
      raise "PreDownload failed: #{response.code} #{response.message}"
    end

    # Parse the response to get the download URL
    result = JSON.parse(response.body)
    download_url = result['download-url']

    raise 'PreDownload response missing download-url' unless download_url.present?

    # Rails.logger.info "[AMB IDR] Received temporary download URL: #{download_url}"
    download_url
  end

  def download_from_url(url)
    # Rails.logger.info '[AMB IDR] Downloading from temporary URL'

    # Simple GET request to the temporary URL (no authentication headers)
    response = HTTParty.get(
      url,
      timeout: 60,
      follow_redirects: true
    )

    unless response.success?
      Rails.logger.error "[AMB IDR] Download failed: #{response.code} #{response.message}"
      raise "Download from temporary URL failed: #{response.code} #{response.message}"
    end

    response.body
    # Rails.logger.info "[AMB IDR] Downloaded #{encrypted_data.bytesize} bytes of encrypted data"
  end

  def decrypt_data(encrypted_data)
    # Rails.logger.info '[AMB IDR] Decrypting Interactive Data Reference'

    # The decryption key can be in either 'dataRefSig' or 'key' field
    decryption_key = @idr_data['dataRefSig'] || @idr_data['key']

    raise 'Missing decryption key for IDR decryption' unless decryption_key.present?

    # Rails.logger.info "[AMB IDR] Using decryption key from field: #{@idr_data['dataRefSig'].present? ? 'dataRefSig' : 'key'}"

    # Use the existing attachment cipher service for decryption
    # The IDR uses the same AES-256-CTR encryption as attachments
    decrypted_data = AppleMessagesForBusiness::AttachmentCipherService.decrypt(
      encrypted_data,
      decryption_key
    )

    # Rails.logger.info "[AMB IDR] Decrypted #{decrypted_data.bytesize} bytes of data"

    # Try /decodePayload first (Python reference approach)
    # If it fails with 403, fall back to manual decompression
    begin
      call_decode_payload(decrypted_data)
      # Rails.logger.info '[AMB IDR] Successfully decoded via /decodePayload'

    rescue StandardError => e
      raise e unless e.message.include?('403') || e.message.include?('Forbidden')

      Rails.logger.warn '[AMB IDR] /decodePayload returned 403, falling back to manual decompression'
      manual_decompress_and_parse(decrypted_data)
    end
  end

  def call_decode_payload(decrypted_data)
    # Rails.logger.info '[AMB IDR] Calling /decodePayload to parse interactive data'
    # Rails.logger.info "[AMB IDR] Decrypted data size: #{decrypted_data.bytesize} bytes"

    # Headers from Python reference (lines 108-114)
    headers = {
      'Authorization' => "Bearer #{@channel.generate_jwt_token}",
      'source-id' => @channel.business_id,  # FIXED: Use business ID, not BID
      'Content-Type' => 'application/octet-stream',  # Binary data content type
      'accept' => '*/*',
      'accept-encoding' => 'gzip, deflate',
      'bid' => @idr_data['bid']
    }

    # Rails.logger.info "[AMB IDR] DecodePayload request for bid: #{@idr_data['bid']}, business_id: #{@channel.business_id}"

    response = HTTParty.post(
      "#{MSP_GATEWAY_URL}/decodePayload",
      headers: headers,
      body: decrypted_data,
      timeout: 30
    )

    unless response.success?
      Rails.logger.error "[AMB IDR] DecodePayload failed: #{response.code} #{response.message}"
      Rails.logger.error "[AMB IDR] DecodePayload response body: #{response.body}"
      raise "DecodePayload failed: #{response.code} #{response.message}"
    end

    # Parse the response - it should be JSON
    interactive_data = JSON.parse(response.body)
    # Rails.logger.info '[AMB IDR] Successfully decoded interactive data via /decodePayload'
    # Rails.logger.info "[AMB IDR] Decoded data keys: #{interactive_data.keys.inspect}"

    # COMPREHENSIVE DEBUG: Log the entire structure
    # log_interactive_data_structure(interactive_data, 'decodePayload response')

    # Remove image bitmaps to keep payload manageable (per Python reference line 159)
    interactive_data.delete('images') if interactive_data.key?('images')

    interactive_data
  rescue JSON::ParserError => e
    Rails.logger.error "[AMB IDR] Failed to parse decodePayload response as JSON: #{e.message}"
    Rails.logger.error "[AMB IDR] Response body: #{response.body[0..500]}"
    raise "DecodePayload response is not valid JSON: #{e.message}"
  end

  def manual_decompress_and_parse(decrypted_data)
    # Rails.logger.info '[AMB IDR] Manually decompressing gzipped data'
    # Rails.logger.info "[AMB IDR] Encrypted data size: #{decrypted_data.bytesize} bytes"

    # The decrypted data is gzip compressed, decompress it
    begin
      gz = Zlib::GzipReader.new(StringIO.new(decrypted_data))
      decompressed_data = gz.read
      gz.close
      # Rails.logger.info "[AMB IDR] Decompressed #{decompressed_data.bytesize} bytes of data"
    rescue Zlib::GzipFile::Error => e
      Rails.logger.warn "[AMB IDR] Data is not gzipped: #{e.message}, using as-is"
      decompressed_data = decrypted_data
    end

    # Log first bytes to identify format
    # Rails.logger.info "[AMB IDR] First 20 bytes: #{decompressed_data[0..19].inspect}"

    # The decompressed data should be binary plist or JSON
    begin
      # Check if it's a binary plist (starts with 'bplist')
      interactive_data = if decompressed_data.start_with?('bplist')
                           # Rails.logger.info '[AMB IDR] Data is binary plist format, converting using plutil'
                           convert_binary_plist_to_hash(decompressed_data)
                         # Rails.logger.info '[AMB IDR] Successfully parsed binary plist'
                         else
                           # Try parsing as JSON
                           JSON.parse(decompressed_data)
                           # Rails.logger.info '[AMB IDR] Successfully parsed JSON'
                         end

      # Remove image bitmaps to keep payload manageable
      interactive_data.delete('images') if interactive_data.key?('images')

      # Rails.logger.info "[AMB IDR] Parsed data keys: #{interactive_data.keys.inspect}"

      # COMPREHENSIVE DEBUG: Log the entire structure
      # log_interactive_data_structure(interactive_data, 'manual parse')

      interactive_data
    rescue JSON::ParserError => e
      Rails.logger.error "[AMB IDR] Failed to parse as JSON: #{e.message}"
      Rails.logger.error "[AMB IDR] First 100 bytes: #{decompressed_data[0..99].inspect}"
      raise "IDR decryption produced invalid JSON: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "[AMB IDR] Failed to parse data: #{e.message}"
      Rails.logger.error "[AMB IDR] First 100 bytes: #{decompressed_data[0..99].inspect}"
      raise "IDR parsing failed: #{e.message}"
    end
  end

  def convert_binary_plist_to_hash(binary_plist_data)
    # Use macOS plutil to convert binary plist to XML first, then parse
    require 'tempfile'

    Tempfile.create(['idr_plist', '.plist']) do |plist_file|
      plist_file.binmode
      plist_file.write(binary_plist_data)
      plist_file.flush

      # Convert binary plist to XML using plutil (JSON fails with embedded images)
      xml_output = `plutil -convert xml1 -o - #{plist_file.path} 2>&1`

      raise "Failed to convert binary plist: #{xml_output}" unless $?.success?

      # Parse the XML plist manually to extract key fields
      parse_plist_xml(xml_output)
    end
  end

  def parse_plist_xml(xml_string)
    # Simple XML parsing to extract interactive data fields
    # This avoids issues with embedded binary image data
    require 'rexml/document'

    doc = REXML::Document.new(xml_string)
    result = {}

    # Navigate to the main dict element
    dict = doc.elements['plist/dict']
    return {} unless dict

    # Extract key-value pairs
    current_key = nil
    dict.elements.each do |element|
      if element.name == 'key'
        current_key = element.text
      elsif current_key
        value = extract_plist_value(element)
        result[current_key] = value unless current_key == 'images' # Skip images
        current_key = nil
      end
    end

    # Rails.logger.info "[AMB IDR] Extracted plist keys: #{result.keys.inspect}"

    # For NSKeyedArchiver format, decode the structure to extract form data
    if result['$archiver'] == 'NSKeyedArchiver' && result['$objects'] && result['$top']
      # Rails.logger.info '[AMB IDR] Decoding NSKeyedArchiver structure for form data'
      decoded = decode_nskeyedarchiver(result)
      # Rails.logger.info "[AMB IDR] Decoded NSKeyedArchiver keys: #{decoded.keys.inspect}"
      return decoded
    end

    result
  end

  def extract_plist_value(element)
    case element.name
    when 'string'
      element.text
    when 'integer'
      element.text.to_i
    when 'real'
      element.text.to_f
    when 'true'
      true
    when 'false'
      false
    when 'dict'
      hash = {}
      current_key = nil
      element.elements.each do |child|
        if child.name == 'key'
          current_key = child.text
        elsif current_key
          hash[current_key] = extract_plist_value(child)
          current_key = nil
        end
      end
      hash
    when 'array'
      element.elements.map { |child| extract_plist_value(child) }
    end
  end

  def self.process_idr_response(idr_data, channel)
    service = new(idr_data: idr_data, channel: channel)
    service.retrieve_and_decrypt
  end

  # Decode NSKeyedArchiver format to extract form data
  # NSKeyedArchiver stores objects in $objects array with CF$UID references
  def decode_nskeyedarchiver(archiver_data)
    objects = archiver_data['$objects']
    top = archiver_data['$top']

    return {} unless objects && top

    # Get root object
    root_uid = top['root']
    return {} unless root_uid && root_uid['CF$UID']

    root_obj = resolve_uid(root_uid['CF$UID'], objects)

    # Rails.logger.info "[AMB IDR] 🔍 DEBUG: Root object type: #{root_obj.class.name}"
    # Rails.logger.info "[AMB IDR] 🔍 DEBUG: Root object keys: #{root_obj.keys.inspect}" if root_obj.is_a?(Hash)
    # Rails.logger.info "[AMB IDR] 🔍 DEBUG: Root object sample: #{root_obj.inspect[0..500]}"

    # Try to find NS.keys and NS.objects (NSKeyedArchiver dict format)
    if root_obj.is_a?(Hash) && root_obj['NS.keys'].is_a?(Array) && root_obj['NS.objects'].is_a?(Array)
      # Rails.logger.info '[AMB IDR] Found NS.keys/NS.objects structure, resolving dictionary'
      resolved_dict = resolve_ns_dictionary(root_obj, objects)
      # Rails.logger.info "[AMB IDR] Resolved dictionary keys: #{resolved_dict.keys.inspect}"

      # Fully resolve all nested CF$UID references in the dictionary
      fully_resolved = resolve_object_recursive(resolved_dict, objects, max_depth: 5)
      # Rails.logger.info "[AMB IDR] 🔍 DEBUG: Fully resolved dictionary keys: #{fully_resolved.keys.inspect}"

      # Check if URL field contains form data
      if fully_resolved.key?('URL')
        url_value = fully_resolved['URL']
        # Rails.logger.info "[AMB IDR] 🔍 DEBUG: URL value type: #{url_value.class.name}"
        # Rails.logger.info "[AMB IDR] 🔍 DEBUG: URL value: #{url_value.inspect[0..500]}"

        # Handle both string and dict formats
        url_string = if url_value.is_a?(String)
                       url_value
                     elsif url_value.is_a?(Hash) && (url_value['NS.base'] || url_value['NS.relative'])
                       # Fallback: manually combine NS.base and NS.relative if not already resolved
                       base = url_value['NS.base']
                       relative = url_value['NS.relative']
                       if base.nil? || base == '$null' || base.to_s.empty?
                         relative.to_s
                       else
                         "#{base}#{relative}"
                       end
                     end

        if url_string.present? && url_string.include?('?')
          # URL contains query parameters - likely form data
          Rails.logger.info '[AMB IDR] Found URL with parameters, parsing for form data'
          form_data = parse_url_encoded_form_data(url_string)
          return form_data if form_data.present?
        end
      end

      # Check if data field contains form data
      if fully_resolved.key?('data')
        data_value = fully_resolved['data']
        # Rails.logger.info "[AMB IDR] 🔍 DEBUG: data value type: #{data_value.class.name}"
        # Rails.logger.info "[AMB IDR] 🔍 DEBUG: data value: #{data_value.inspect[0..200]}"

        if data_value.is_a?(String) && data_value.include?('?')
          # Data is a URL string - parse it for form data
          Rails.logger.info '[AMB IDR] Found URL string in data field, parsing for form data'
          form_data = parse_url_encoded_form_data(data_value)
          return form_data if form_data.present?
        end
      end

      # Return fully resolved dictionary
      return fully_resolved
    end

    # For forms, look for 'data' key in root object
    if root_obj.is_a?(Hash) && root_obj.key?('data')
      data_uid = root_obj['data']
      data_obj = resolve_uid(data_uid['CF$UID'], objects) if data_uid.is_a?(Hash) && data_uid['CF$UID']

      if data_obj.is_a?(String)
        # Data is a URL string with encoded parameters - try to parse it
        Rails.logger.info "[AMB IDR] Found URL string in data: #{data_obj[0..100]}"
        return parse_url_encoded_form_data(data_obj)
      elsif data_obj.is_a?(Hash)
        # Data is an object - resolve it recursively
        resolved_data = resolve_object_recursive(data_obj, objects, max_depth: 5)
        return { 'data' => resolved_data }
      end
    end

    # Fallback: return the raw archiver structure
    Rails.logger.warn '[AMB IDR] Could not decode NSKeyedArchiver structure for form data'
    archiver_data
  end

  # Resolve a CF$UID reference to the actual object
  def resolve_uid(uid, objects)
    return nil if uid.nil? || uid >= objects.length

    objects[uid]
  end

  # Resolve NSKeyedArchiver dictionary format (NS.keys + NS.objects)
  def resolve_ns_dictionary(dict_obj, objects)
    keys = dict_obj['NS.keys'] || []
    values = dict_obj['NS.objects'] || []

    result = {}
    keys.each_with_index do |key_ref, index|
      key = if key_ref.is_a?(Hash) && key_ref['CF$UID']
              resolve_uid(key_ref['CF$UID'], objects)
            else
              key_ref
            end

      value_ref = values[index]
      value = if value_ref.is_a?(Hash) && value_ref['CF$UID']
                resolve_uid(value_ref['CF$UID'], objects)
              else
                value_ref
              end

      result[key] = value if key
    end
    result
  end

  # Recursively resolve an object and its CF$UID references
  def resolve_object_recursive(obj, objects, depth: 0, max_depth: 3)
    return obj if depth >= max_depth
    return obj unless obj.is_a?(Hash)

    # If this is a CF$UID reference, resolve it
    if obj.key?('CF$UID')
      resolved = resolve_uid(obj['CF$UID'], objects)
      return resolve_object_recursive(resolved, objects, depth: depth + 1, max_depth: max_depth)
    end

    # Resolve all values in the hash
    result = {}
    obj.each do |key, value|
      result[key] = if value.is_a?(Hash)
                      resolve_object_recursive(value, objects, depth: depth + 1, max_depth: max_depth)
                    elsif value.is_a?(Array)
                      value.map { |v| resolve_object_recursive(v, objects, depth: depth + 1, max_depth: max_depth) }
                    else
                      value
                    end
    end

    # Special handling for NSURL objects (NS.base + NS.relative)
    if result.key?('NS.base') && result.key?('NS.relative')
      base = result['NS.base']
      relative = result['NS.relative']

      # Combine base and relative into full URL
      # If base is "$null" or nil, just use relative
      return relative.to_s if base.nil? || base == '$null' || base.to_s.empty?

      # Combine base and relative
      return "#{base}#{relative}"

    end

    result
  end

  # Parse URL-encoded form data from NSKeyedArchiver URL string
  def parse_url_encoded_form_data(url_string)
    require 'uri'
    require 'cgi'
    require 'base64'
    require 'json'

    # Rails.logger.info "[AMB IDR] 🔍 Parsing URL for form data: #{url_string[0..200]}"

    # Extract query parameters
    params = CGI.parse(url_string.sub(/^[^?]*\?/, ''))

    # Rails.logger.info "[AMB IDR] 🔍 URL params keys: #{params.keys.inspect}"
    # Rails.logger.info "[AMB IDR] 🔍 URL params: #{params.inspect[0..500]}"

    # Look for form data in various possible parameters
    form_selections = []

    # Try to find form data in receivedMessage or replyMessage parameters
    %w[receivedMessage replyMessage data selections].each do |param_key|
      next unless params[param_key].present?

      param_values = params[param_key]
      param_values.each do |param_value|
        # Try base64 decode first
        decoded = if param_value.include?('=') || param_value.length % 4 == 0
                    Base64.decode64(param_value)
                  else
                    param_value
                  end

        # Try to parse as JSON
        parsed = JSON.parse(decoded)
        # Rails.logger.info "[AMB IDR] 🔍 Decoded #{param_key}: #{parsed.inspect[0..500]}"

        # Extract selections if present
        if parsed.is_a?(Hash)
          if parsed['selections'].present?
            form_selections.concat(parsed['selections'])
          elsif parsed['dynamic'].present? && parsed['dynamic']['selections'].present?
            form_selections.concat(parsed['dynamic']['selections'])
          end
        elsif parsed.is_a?(Array)
          form_selections.concat(parsed)
        end
      rescue JSON::ParserError, ArgumentError => e
        Rails.logger.warn "[AMB IDR] Failed to parse #{param_key}: #{e.message}"
      end
    end

    if form_selections.any?
      # Rails.logger.info "[AMB IDR] ✅ Extracted #{form_selections.length} form selections from URL"
      # Rails.logger.info "[AMB IDR] 🔍 Form selections: #{form_selections.inspect}"

      # Return form data in the expected format
      {
        'data' => {
          'dynamic' => {
            'template' => 'messageForms',
            'selections' => form_selections
          }
        }
      }
    else
      Rails.logger.warn '[AMB IDR] No form selections found in URL parameters'
      {}
    end
  end

  # Comprehensively log the entire interactive data structure
  # This helps identify where form selections and other data are actually located
  def log_interactive_data_structure(data, source, prefix = '', depth = 0, max_depth = 10)
    return if depth >= max_depth

    case data
    when Hash
      Rails.logger.info "#{prefix}[AMB IDR] (#{source}) Hash with #{data.keys.length} keys: #{data.keys.inspect}"
      data.each do |key, value|
        value_preview = case value
                        when Hash
                          "{...#{value.keys.length} keys}"
                        when Array
                          "[...#{value.length} items]"
                        when String
                          value.length > 50 ? "\"#{value[0..50]}...\"" : "\"#{value}\""
                        when NilClass
                          'nil'
                        else
                          value.inspect
                        end
        Rails.logger.info "#{prefix}[AMB IDR] (#{source})   #{key}: #{value.class.name} = #{value_preview}"
        log_interactive_data_structure(value, source, "#{prefix}  ", depth + 1, max_depth)
      end
    when Array
      Rails.logger.info "#{prefix}[AMB IDR] (#{source}) Array with #{data.length} items"
      data.each_with_index do |item, index|
        item_preview = case item
                       when Hash
                         "{...#{item.keys.length} keys}"
                       when Array
                         "[...#{item.length} items]"
                       when String
                         item.length > 50 ? "\"#{item[0..50]}...\"" : "\"#{item}\""
                       when NilClass
                         'nil'
                       else
                         item.inspect
                       end
        Rails.logger.info "#{prefix}[AMB IDR] (#{source})   [#{index}]: #{item.class.name} = #{item_preview}"
        log_interactive_data_structure(item, source, "#{prefix}  ", depth + 1, max_depth)
      end
    when String
      truncated = data.length > 200 ? "#{data[0..200]}..." : data
      Rails.logger.info "#{prefix}[AMB IDR] (#{source}) String(#{data.length} chars): #{truncated.inspect}"
    when NilClass
      Rails.logger.info "#{prefix}[AMB IDR] (#{source}) nil"
    else
      Rails.logger.info "#{prefix}[AMB IDR] (#{source}) #{data.class.name}: #{data.inspect}"
    end
  rescue StandardError => e
    Rails.logger.error "#{prefix}[AMB IDR] (#{source}) Error logging structure: #{e.message}"
  end
end
