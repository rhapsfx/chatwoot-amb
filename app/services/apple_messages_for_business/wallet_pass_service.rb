# frozen_string_literal: true

# Generates a signed Apple Wallet (.pkpass) file for a guitar lesson pickup pass.
#
# The pass includes the customer name, guitar model, store, pickup time, a QR code,
# and a geo-trigger location so iOS shows a lock-screen notification near the store.
#
# Required ENV vars:
#   WALLET_PASS_TYPE_ID  – e.g. pass.net.rhaps.acoustichouse
#   WALLET_TEAM_ID       – Apple Developer Team ID
#   WALLET_CERT_PEM      – PEM-encoded signing certificate
#   WALLET_KEY_PEM       – PEM-encoded private key
#   WALLET_WWDR_PEM      – PEM-encoded Apple WWDR intermediate certificate
#
# Required image assets in app/assets/images/wallet/:
#   icon.png, icon@2x.png, logo.png, logo@2x.png
#
class AppleMessagesForBusiness::WalletPassService
  ASSETS_DIR = Rails.root.join('app/assets/images/wallet').freeze

  IMAGE_FILES = {
    'icon.png' => 'icon.png',
    'icon@2x.png' => 'icon@2x.png',
    'logo.png' => 'logo.png',
    'logo@2x.png' => 'logo@2x.png'
  }.freeze

  def initialize(conversation)
    @conversation = conversation
  end

  # Returns the raw binary .pkpass data (a signed ZIP archive).
  def generate
    validate_env!

    Passbook.setup do |config|
      config.p12_certificate = ENV.fetch('WALLET_CERT_PEM')
      config.p12_key         = ENV.fetch('WALLET_KEY_PEM')
      config.p12_password    = ENV.fetch('WALLET_KEY_PASSWORD', '')
      config.p12_intermediate_certificate = ENV.fetch('WALLET_WWDR_PEM')
    end

    pkpass = Passbook::PKPass.new(build_pass_json)
    attach_images(pkpass)
    pkpass.stream.string
  end

  private

  def attrs
    @conversation.custom_attributes || {}
  end

  def customer_name
    attrs['customer_name'].presence || 'Guest'
  end

  def selected_guitar
    attrs['selected_guitar'].presence || 'Guitar'
  end

  def selected_store
    attrs['selected_store_name'].presence || 'Apple Store'
  end

  def formatted_time
    timeslot = attrs['selected_timeslot']
    return 'TBD' if timeslot.blank?

    timeslot.is_a?(Hash) ? (timeslot['formatted_time'] || timeslot['startTime'] || 'TBD') : timeslot.to_s
  end

  def serial_number
    return attrs['wallet_serial_number'] if attrs['wallet_serial_number'].present?

    sn = "AH-#{@conversation.id}-#{Time.now.to_i}"
    @conversation.custom_attributes ||= {}
    @conversation.custom_attributes['wallet_serial_number'] = sn
    @conversation.save!
    sn
  end

  def store_coordinates
    lat = attrs['store_search_lat']
    lon = attrs['store_search_lon']
    return nil unless lat && lon

    { latitude: lat.to_f, longitude: lon.to_f }
  end

  def build_pass_json
    pass = base_pass_structure.merge(generic: generic_fields, barcode: barcode_data)
    coords = store_coordinates
    pass[:locations] = [geo_trigger(coords)] if coords
    pass.to_json
  end

  def base_pass_structure
    {
      formatVersion: 1,
      passTypeIdentifier: ENV.fetch('WALLET_PASS_TYPE_ID'),
      teamIdentifier: ENV.fetch('WALLET_TEAM_ID'),
      serialNumber: serial_number,
      description: 'Guitar Lesson Pickup Pass',
      organizationName: 'Acoustic House',
      logoText: 'Acoustic House',
      foregroundColor: 'rgb(255, 255, 255)',
      backgroundColor: 'rgb(20, 20, 30)',
      labelColor: 'rgb(160, 160, 180)'
    }
  end

  def generic_fields
    {
      primaryFields: [{ key: 'name', label: 'YOUR LESSON', value: customer_name }],
      secondaryFields: [{ key: 'guitar', label: 'GUITAR', value: selected_guitar },
                        { key: 'store', label: 'STORE', value: selected_store }],
      auxiliaryFields: [{ key: 'pickup_time', label: 'PICKUP TIME', value: formatted_time }]
    }
  end

  def barcode_data
    {
      message: serial_number,
      format: 'PKBarcodeFormatQR',
      messageEncoding: 'iso-8859-1',
      altText: "#{customer_name} | #{selected_guitar} | #{formatted_time} | #{selected_store}"
    }
  end

  def geo_trigger(coords)
    {
      latitude: coords[:latitude],
      longitude: coords[:longitude],
      relevantText: 'Your guitar lesson is nearby! 🎸'
    }
  end

  def attach_images(pkpass)
    IMAGE_FILES.each do |pass_filename, asset_filename|
      file_path = ASSETS_DIR.join(asset_filename)
      next unless File.exist?(file_path)

      pkpass.addFile pass_filename, data: File.binread(file_path)
    end
  end

  def validate_env!
    missing = %w[WALLET_PASS_TYPE_ID WALLET_TEAM_ID WALLET_CERT_PEM WALLET_KEY_PEM WALLET_WWDR_PEM].select do |key|
      ENV[key].blank?
    end
    raise "WalletPassService: missing ENV vars: #{missing.join(', ')}" if missing.any?
  end
end
