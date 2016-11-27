# frozen_string_literal: true

class ProcessInteractionService < BaseService
  ACTIVITY_NS = 'http://activitystrea.ms/spec/1.0/'

  # Record locally the remote interaction with our user
  # @param [String] envelope Salmon envelope
  # @param [Account] target_account Account the Salmon was addressed to
  def call(envelope, target_account)
    body = salmon.unpack(envelope)

    xml = Nokogiri::XML(body)
    xml.encoding = 'utf-8'

    return unless contains_author?(xml)

    username = xml.at_xpath('/xmlns:entry/xmlns:author/xmlns:name').content
    url      = xml.at_xpath('/xmlns:entry/xmlns:author/xmlns:uri').content
    domain   = Addressable::URI.parse(url).host
    account  = Account.find_by(username: username, domain: domain)

    return if DomainBlock.blocked?(domain)

    if account.nil?
      account = follow_remote_account_service.call("#{username}@#{domain}")
    end

    if salmon.verify(envelope, account.keypair)
      update_remote_profile_service.call(xml.at_xpath('/xmlns:entry'), account, true)

      case verb(xml)
      when :follow
        follow!(account, target_account)
      when :unfollow
        unfollow!(account, target_account)
      when :favorite
        favourite!(xml, account)
      when :post
        add_post!(body, account) if mentions_account?(xml, target_account)
      when :share
        add_post!(body, account) unless status(xml).nil?
      when :delete
        delete_post!(xml, account)
      when :'update-profile'
        refetch_profile!(account)
      end
    end
  rescue Goldfinger::Error, HTTP::Error, OStatus2::BadSalmonError
    nil
  end

  private

  def contains_author?(xml)
    !(xml.at_xpath('/xmlns:entry/xmlns:author/xmlns:name').nil? || xml.at_xpath('/xmlns:entry/xmlns:author/xmlns:uri').nil?)
  end

  def mentions_account?(xml, account)
    xml.xpath('/xmlns:entry/xmlns:link[@rel="mentioned"]').each { |mention_link| return true if mention_link.attribute('href').value == TagManager.instance.url_for(account) }
    false
  end

  def verb(xml)
    xml.at_xpath('//activity:verb', activity: ACTIVITY_NS).content.gsub('http://activitystrea.ms/schema/1.0/', '').gsub('http://ostatus.org/schema/1.0/', '').to_sym
  rescue
    :post
  end

  def follow!(account, target_account)
    follow = account.follow!(target_account)
    NotifyService.new.call(target_account, follow)
  end

  def unfollow!(account, target_account)
    account.unfollow!(target_account)
  end

  def delete_post!(xml, account)
    status = Status.find(activity_id(xml))

    return if status.nil?

    remove_status_service.call(status) if account.id == status.account_id
  end

  def favourite!(xml, from_account)
    current_status = status(xml)
    favourite = current_status.favourites.where(account: from_account).first_or_create!(account: from_account)
    NotifyService.new.call(current_status.account, favourite)
  end

  def add_post!(body, account)
    process_feed_service.call(body, account)
  end

  def refetch_profile!(account)
    response = HTTP.timeout(:per_operation, write: 20, connect: 20, read: 50).get(account.remote_url)
    xml      = Nokogiri::XML(response)
    update_remote_profile_service.call(xml.at_xpath('/xmlns:feed'), account)
  end

  def status(xml)
    Status.find(TagManager.instance.unique_tag_to_local_id(activity_id(xml), 'Status'))
  end

  def activity_id(xml)
    xml.at_xpath('//activity:object', activity: ACTIVITY_NS).at_xpath('./xmlns:id').content
  end

  def salmon
    @salmon ||= OStatus2::Salmon.new
  end

  def follow_remote_account_service
    @follow_remote_account_service ||= FollowRemoteAccountService.new
  end

  def process_feed_service
    @process_feed_service ||= ProcessFeedService.new
  end

  def update_remote_profile_service
    @update_remote_profile_service ||= UpdateRemoteProfileService.new
  end

  def remove_status_service
    @remove_status_service ||= RemoveStatusService.new
  end
end
