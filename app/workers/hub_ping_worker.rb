# frozen_string_literal: true

class HubPingWorker
  include Sidekiq::Worker
  include RoutingHelper

  def perform(account_id)
    account = Account.find(account_id)
    Pubsubhubbub.publish(pubsubhubbub_url, account_url(account, format: 'atom'))
  end
end
