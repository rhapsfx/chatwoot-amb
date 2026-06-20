class SharedAppleImagePresenter < SimpleDelegator
  # Returns a hash representation suitable for JSON API responses
  def as_json(_options = {})
    {
      id: id,
      account_id: account_id,
      identifier: identifier,
      image_type: image_type,
      description: description,
      original_name: original_name,
      metadata: metadata || {},
      image_url: image_url,
      image_attached: image_attached?,
      image_size: image_size,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  # Returns a hash with base64 image data included (for uploads/downloads)
  def as_json_with_data
    as_json.merge(
      image_data_base64: image_data_base64
    )
  end

  # Class method to serialize a collection of images
  def self.collection(images)
    images.map { |image| new(image).as_json }
  end

  # Class method to serialize a collection with image data
  def self.collection_with_data(images)
    images.map { |image| new(image).as_json_with_data }
  end
end
