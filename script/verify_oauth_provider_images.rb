#!/usr/bin/env ruby
# frozen_string_literal: true

# Verifies OAuth provider images are correctly configured for SendAuthenticationService
# Expected identifiers: linkedin_logo, google_logo, facebook_logo

puts "\n🔍 OAuth Provider Images Verification\n"
puts '=' * 60

# Expected OAuth provider images
OAUTH_PROVIDERS = {
  'linkedin' => {
    identifier: 'linkedin_logo',
    expected_files: ['linkedin.png', 'LinkedIn.png'],
    description: 'LinkedIn logo for OAuth authentication'
  },
  'google' => {
    identifier: 'google_logo',
    expected_files: ['google.png', 'google.webp', 'Google.png'],
    description: 'Google logo for OAuth authentication'
  },
  'facebook' => {
    identifier: 'facebook_logo',
    expected_files: ['facebook.png', 'Facebook.png'],
    description: 'Facebook logo for OAuth authentication'
  }
}.freeze

# Get all accounts with Apple Messages channels
accounts_with_amb = Account.joins(:inboxes)
                           .where(inboxes: { channel_type: 'Channel::AppleMessagesForBusiness' })
                           .distinct

if accounts_with_amb.empty?
  puts '❌ No accounts found with Apple Messages for Business channels'
  exit 1
end

puts "\n📊 Found #{accounts_with_amb.count} account(s) with AMB channels:"
accounts_with_amb.each do |account|
  puts "  • Account ##{account.id}: #{account.name}"
end

results = {
  found: [],
  missing: [],
  misnamed: [],
  to_create: []
}

puts "\n" + ('=' * 60)
puts 'Checking OAuth Provider Images...'
puts '=' * 60

accounts_with_amb.each do |account|
  puts "\n🏢 Account ##{account.id}: #{account.name}"

  OAUTH_PROVIDERS.each do |provider, config|
    identifier = config[:identifier]

    # Check if image exists with correct identifier
    existing = SharedAppleImage.find_by(
      account_id: account.id,
      identifier: identifier
    )

    if existing
      has_attachment = existing.image.attached?
      puts "  ✅ #{identifier.ljust(20)} - Found #{has_attachment ? 'with' : 'WITHOUT'} attachment"

      if has_attachment
        results[:found] << {
          account: account,
          provider: provider,
          image: existing
        }
      else
        results[:missing] << {
          account: account,
          provider: provider,
          identifier: identifier,
          reason: 'Image record exists but no attachment'
        }
      end
    else
      # Check if image exists with wrong identifier (original filename)
      config[:expected_files].each do |filename|
        misnamed = SharedAppleImage.where(account_id: account.id)
                                   .where('identifier LIKE ? OR original_name LIKE ?',
                                          "%#{filename.downcase.split('.').first}%",
                                          "%#{filename}%")
                                   .first

        next unless misnamed && misnamed.image.attached?

        puts "  ⚠️  #{identifier.ljust(20)} - Found as '#{misnamed.identifier}' (needs rename)"
        results[:misnamed] << {
          account: account,
          provider: provider,
          image: misnamed,
          correct_identifier: identifier
        }
        break
      end

      unless results[:misnamed].any? { |m| m[:account].id == account.id && m[:provider] == provider }
        puts "  ❌ #{identifier.ljust(20)} - Missing"
        results[:missing] << {
          account: account,
          provider: provider,
          identifier: identifier,
          reason: 'Image not found'
        }

        # Check if image file exists in public/
        config[:expected_files].each do |filename|
          public_path = Rails.public_path.join(filename)
          next unless File.exist?(public_path)

          results[:to_create] << {
            account: account,
            provider: provider,
            identifier: identifier,
            file_path: public_path,
            description: config[:description]
          }
          puts "     💡 Found file: public/#{filename}"
          break
        end
      end
    end
  end
end

# Summary
puts "\n" + ('=' * 60)
puts '📋 Summary'
puts '=' * 60
puts "✅ Correctly configured: #{results[:found].count}"
puts "⚠️  Need renaming: #{results[:misnamed].count}"
puts "❌ Missing: #{results[:missing].count}"
puts "💡 Can auto-create: #{results[:to_create].count}"

# Show details of issues
if results[:misnamed].any?
  puts "\n⚠️  Images that need renaming:"
  results[:misnamed].each do |item|
    puts "  • Account ##{item[:account].id}: '#{item[:image].identifier}' → '#{item[:correct_identifier]}'"
  end
end

if results[:missing].any? && results[:to_create].empty?
  puts "\n❌ Missing images (no files found in public/):"
  results[:missing].each do |item|
    puts "  • Account ##{item[:account].id}: #{item[:identifier]} - #{item[:reason]}"
  end
end

# Offer to fix
if results[:misnamed].any? || results[:to_create].any?
  puts "\n" + ('=' * 60)
  puts '🔧 Auto-Fix Available'
  puts '=' * 60

  if results[:misnamed].any?
    puts "\nRename misnamed images? (yes/no)"
    print '> '
    if gets.chomp.downcase == 'yes'
      results[:misnamed].each do |item|
        puts "  Renaming '#{item[:image].identifier}' → '#{item[:correct_identifier]}'..."
        item[:image].update!(
          identifier: item[:correct_identifier],
          description: OAUTH_PROVIDERS[item[:provider]][:description]
        )
        puts '  ✅ Renamed'
      end
    end
  end

  if results[:to_create].any?
    puts "\nCreate missing images from public/ files? (yes/no)"
    print '> '
    if gets.chomp.downcase == 'yes'
      results[:to_create].each do |item|
        puts "  Creating #{item[:identifier]} for Account ##{item[:account].id}..."

        image = SharedAppleImage.create!(
          account_id: item[:account].id,
          identifier: item[:identifier],
          description: item[:description],
          image_type: 'branding',
          original_name: File.basename(item[:file_path])
        )

        image.image.attach(
          io: File.open(item[:file_path]),
          filename: File.basename(item[:file_path]),
          content_type: item[:file_path].to_s.end_with?('.webp') ? 'image/webp' : 'image/png'
        )

        puts '  ✅ Created with attachment'
      end
    end
  end

  puts "\nRun verification again? (yes/no)"
  print '> '
  if gets.chomp.downcase == 'yes'
    puts "\n" + ('=' * 60)
    exec($PROGRAM_NAME)
  end
end

puts "\n✅ Verification complete!\n"
puts "\n💡 To use in SendAuthenticationService:"
puts "   - LinkedIn: identifier 'linkedin_logo'"
puts "   - Google:   identifier 'google_logo'"
puts "   - Facebook: identifier 'facebook_logo'"
puts "\n"
