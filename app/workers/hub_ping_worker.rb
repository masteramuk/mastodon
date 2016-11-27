# frozen_string_literal: true

class HubPingWorker
  include Sidekiq::Worker
  include RoutingHelper

  def perform(account_id)
    account = Account.find(account_id)
    account.ping!(account_url(account, format: 'atom'), [pubsubhubbub_url])
  end
end
