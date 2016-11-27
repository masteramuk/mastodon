Pubsubhubbub.verify_topic = lambda { |topic_url|
  equal_host = Addressable::URI.parse(topic_url).host == Rails.configuration.x.local_domain
  params     = Rails.application.routes.recognize_path(topic_url)

  equal_host && params[:controller] == 'accounts' && params[:action] == 'show' && params[:format] == 'atom'
}

Pubsubhubbub.render_topic = lambda { |topic_url|
  params  = Rails.application.routes.recognize_path(topic_url)
  account = Account.find_local!(params[:username])

  AccountsController.render(:show, assigns: { account: account, entries: account.stream_entries.order('id desc').with_includes.paginate_by_max_id(20) }, formats: [:atom])
}
