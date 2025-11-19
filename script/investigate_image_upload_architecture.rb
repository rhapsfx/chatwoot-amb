# frozen_string_literal: true

# Investigate image upload architecture and inbox association
# Run with: rails runner script/investigate_image_upload_architecture.rb

puts '=' * 80
puts 'Image Upload Architecture Investigation'
puts '=' * 80
puts ''

puts '=' * 80
puts '1. How Images Get Uploaded'
puts '=' * 80
puts ''

puts 'There are TWO ways images get into AppleListPickerImage table:'
puts ''
puts 'METHOD 1: Manual Upload Scripts'
puts '  - Example: script/upload_messages_icon.rb'
puts '  - Hardcodes inbox_id in the script'
puts '  - Used for: Shared icons like messages_png'
puts ''
puts 'METHOD 2: Automatic Upload on First Send (SendListPickerService)'
puts '  - Location: app/services/apple_messages_for_business/send_list_picker_service.rb'
puts '  - Method: save_images_to_storage (lines 84-196)'
puts '  - Uses: message.inbox_id (dynamic based on which inbox sent the message)'
puts '  - Used for: Embedded template images'
puts ''

puts '=' * 80
puts '2. The Problem'
puts '=' * 80
puts ''

puts '❌ Manual scripts uploaded messages_png to inbox 4'
puts '❌ SendListPickerService auto-uploaded embedded images to inbox 6'
puts "❌ When bot sends from inbox 6, it can't find messages_png in inbox 6"
puts ''

puts '=' * 80
puts '3. Code Analysis: save_images_to_storage'
puts '=' * 80
puts ''

puts 'Key Code (send_list_picker_service.rb:84-196):'
puts ''
puts '  def save_images_to_storage'
puts "    images = content_attributes['images'] || []"
puts '    ...'
puts '    existing_images = AppleListPickerImage'
puts '                      .where(inbox_id: message.inbox_id, identifier: image_identifiers)  ← Uses message.inbox_id!'
puts '    ...'
puts '    picker_image = existing_image || AppleListPickerImage.new('
puts '      account_id: message.account_id,'
puts '      inbox_id: message.inbox_id,  ← Uses message.inbox_id!'
puts "      identifier: image_data['identifier']"
puts '    )'
puts '  end'
puts ''

puts 'This means:'
puts '  - If message is sent from inbox 4 → images uploaded to inbox 4'
puts '  - If message is sent from inbox 6 → images uploaded to inbox 6'
puts '  - Images are INBOX-SPECIFIC, not account-wide'
puts ''

puts '=' * 80
puts '4. Code Analysis: fetch_and_encode_images'
puts '=' * 80
puts ''

puts 'Key Code (send_list_picker_service.rb:289-363):'
puts ''
puts '  def fetch_and_encode_images(identifiers)'
puts '    inbox_id = message.inbox_id  ← Uses message.inbox_id!'
puts '    ...'
puts '    picker_images = AppleListPickerImage'
puts '                    .where(inbox_id: inbox_id, identifier: identifiers)  ← Inbox-scoped query!'
puts '  end'
puts ''

puts 'This means:'
puts "  - Images are fetched from the SAME inbox that's sending the message"
puts '  - If sending from inbox 6, only images in inbox 6 are found'
puts "  - If messages_png is in inbox 4, it won't be found when sending from inbox 6"
puts ''

puts '=' * 80
puts '5. Bot Service: acoustic_house_bot_service.rb'
puts '=' * 80
puts ''

puts 'Key Code (acoustic_house_bot_service.rb:1671-1704):'
puts ''
puts '  def fetch_and_encode_images(identifiers)'
puts '    inbox_id = @conversation.inbox_id  ← Dynamic based on conversation!'
puts '    picker_images = AppleListPickerImage'
puts '                    .where(inbox_id: inbox_id, identifier: identifiers)'
puts '  end'
puts ''

puts 'This means:'
puts '  - Bot uses @conversation.inbox_id (dynamic)'
puts '  - If conversation is in inbox 6, bot looks for images in inbox 6'
puts "  - If messages_png is only in inbox 4, bot can't find it"
puts ''

puts '=' * 80
puts '6. Architecture Decision Points'
puts '=' * 80
puts ''

puts 'OPTION A: Keep Images Inbox-Specific (Current Design)'
puts '  Pros:'
puts '    - Different inboxes can use different branding'
puts '    - Isolation between customer-facing channels'
puts '  Cons:'
puts '    - Must upload shared images to EVERY inbox'
puts '    - Duplication of data'
puts '    - Manual management required'
puts ''

puts 'OPTION B: Make Shared Images Account-Wide'
puts '  Pros:'
puts '    - Upload once, use everywhere'
puts '    - Less duplication'
puts '    - Easier management'
puts '  Cons:'
puts "    - Can't customize per inbox"
puts '    - Requires code changes to handle two image types'
puts ''

puts 'OPTION C: Hybrid Approach (Recommended)'
puts '  - Embedded template images: inbox-specific (current behavior)'
puts '  - Shared system images (messages_png, etc.): account-wide'
puts '  - fetch_and_encode_images checks BOTH inbox AND account scope'
puts ''

puts '=' * 80
puts '7. Current State Analysis'
puts '=' * 80
puts ''

# Find all unique identifiers across all inboxes
all_images = AppleListPickerImage.all.group_by(&:identifier)

puts "Total unique image identifiers: #{all_images.keys.count}"
puts ''

# Find images that exist in multiple inboxes
multi_inbox_images = all_images.select { |_identifier, images| images.map(&:inbox_id).uniq.count > 1 }

if multi_inbox_images.any?
  puts 'Images that exist in MULTIPLE inboxes (likely shared):'
  multi_inbox_images.each do |identifier, images|
    inbox_ids = images.map(&:inbox_id).uniq
    puts "  - #{identifier}: inboxes #{inbox_ids.inspect}"
  end
else
  puts 'No images exist in multiple inboxes yet'
end

puts ''

# Find images that exist in only ONE inbox
single_inbox_images = all_images.select { |_identifier, images| images.map(&:inbox_id).uniq.count == 1 }

puts 'Images that exist in ONLY ONE inbox (likely template-specific):'
single_inbox_images.take(10).each do |identifier, images|
  puts "  - #{identifier}: inbox #{images.first.inbox_id}"
end
puts "  ... and #{single_inbox_images.count - 10} more" if single_inbox_images.count > 10

puts ''

puts '=' * 80
puts '8. Recommendations'
puts '=' * 80
puts ''

puts 'SHORT-TERM FIX (Immediate):'
puts '  1. Copy messages_png to all active inboxes (4, 5, 6)'
puts '  2. Create a script: script/ensure_shared_images_in_all_inboxes.rb'
puts '  3. Run after any new inbox is created'
puts ''

puts 'MEDIUM-TERM FIX (Next Sprint):'
puts '  1. Implement hybrid approach in fetch_and_encode_images'
puts "  2. Add 'shared' flag to AppleListPickerImage model"
puts '  3. Shared images checked account-wide, others inbox-specific'
puts ''

puts 'LONG-TERM FIX (Architecture):'
puts '  1. Create separate SharedAppleImage model for account-wide images'
puts '  2. Keep AppleListPickerImage for inbox-specific template images'
puts '  3. Clear separation of concerns'
puts ''
