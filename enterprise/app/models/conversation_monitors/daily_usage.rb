# == Schema Information
#
# Table name: conversation_monitor_daily_usages
#
#  id               :bigint           not null, primary key
#  calls_count      :integer          default(0), not null
#  limit_reached_at :datetime
#  usage_date       :date             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#
# Indexes
#
#  index_monitor_daily_usage_unique  (account_id,usage_date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#
class ConversationMonitors::DailyUsage < ApplicationRecord
  self.table_name = 'conversation_monitor_daily_usages'

  belongs_to :account

  validates :usage_date, presence: true, uniqueness: { scope: :account_id }
  validates :calls_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.monthly_snapshot(account_id, now = Time.current.utc)
    first_day = now.to_date.beginning_of_month
    resets_at = now.beginning_of_month.next_month
    records = where(account_id: account_id, usage_date: first_day...resets_at.to_date)
              .order(:usage_date).pluck(:usage_date, :calls_count, :limit_reached_at)
    limit = ConversationMonitors::Configuration::MONTHLY_CALL_LIMIT
    used = 0
    limit_reached_at = nil
    records.each do |_, count, reached_at|
      used += count
      limit_reached_at ||= reached_at if used >= limit
    end
    counts = records.to_h { |date, count, _| [date, count] }
    {
      limit: limit, used: used, remaining: [limit - used, 0].max, limit_reached: used >= limit,
      limit_reached_at: limit_reached_at&.to_i, resets_at: resets_at.to_i,
      period_start: first_day.iso8601, timezone: 'UTC',
      daily: (first_day..now.to_date).map { |date| { date: date.iso8601, calls: counts.fetch(date, 0) } }
    }
  end

  # Usage#reserve! holds the account lock across the monthly check and this write.
  def self.record_call!(account_id, at:, limit_reached:)
    daily = find_or_initialize_by(account_id: account_id, usage_date: at.to_date)
    daily.calls_count += 1
    daily.limit_reached_at = at if limit_reached
    daily.save!
  end
end
