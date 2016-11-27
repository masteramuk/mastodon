require 'rails_helper'

RSpec.describe UpdateRemoteProfileService do
  let(:xml) { Nokogiri::XML(File.read(File.join(Rails.root, 'spec', 'fixtures', 'push', 'feed.atom'))).at_xpath('//xmlns:feed') }

  subject { UpdateRemoteProfileService.new }

  before do
    stub_request(:get, 'https://quitter.no/avatar/7477-300-20160211190340.png').to_return(request_fixture('avatar.txt'))
  end

  context 'with updated details' do
    let(:remote_account) { Fabricate(:account, username: 'bob', domain: 'example.com') }

    before do
      subject.call(xml, remote_account)
    end

    it 'downloads new avatar' do
      expect(a_request(:get, 'https://quitter.no/avatar/7477-300-20160211190340.png')).to have_been_made
    end

    it 'sets the avatar remote url' do
      expect(remote_account.reload.avatar_remote_url).to eq 'https://quitter.no/avatar/7477-300-20160211190340.png'
    end

    it 'sets display name' do
      expect(remote_account.reload.display_name).to eq 'ＤＩＧＩＴＡＬ ＣＡＴ'
    end

    it 'sets note' do
      expect(remote_account.reload.note).to eq 'Software engineer, free time musician and ＤＩＧＩＴＡＬ ＳＰＯＲＴＳ enthusiast. Likes cats. Warning: May contain memes'
    end
  end

  context 'with unchanged details' do
    let(:remote_account) { Fabricate(:account, username: 'bob', domain: 'example.com', display_name: 'ＤＩＧＩＴＡＬ ＣＡＴ', note: 'Software engineer, free time musician and ＤＩＧＩＴＡＬ ＳＰＯＲＴＳ enthusiast. Likes cats. Warning: May contain memes', avatar_remote_url: 'https://quitter.no/avatar/7477-300-20160211190340.png') }

    before do
      subject.call(xml, remote_account)
    end

    it 'does not re-download avatar' do
      expect(a_request(:get, 'https://quitter.no/avatar/7477-300-20160211190340.png')).to have_been_made.once
    end

    it 'sets the avatar remote url' do
      expect(remote_account.reload.avatar_remote_url).to eq 'https://quitter.no/avatar/7477-300-20160211190340.png'
    end

    it 'sets display name' do
      expect(remote_account.reload.display_name).to eq 'ＤＩＧＩＴＡＬ ＣＡＴ'
    end

    it 'sets note' do
      expect(remote_account.reload.note).to eq 'Software engineer, free time musician and ＤＩＧＩＴＡＬ ＳＰＯＲＴＳ enthusiast. Likes cats. Warning: May contain memes'
    end
  end

  context 'with update hub URL' do
    let(:remote_account) { Fabricate(:account, hub_url: 'http://oldhub.com', username: 'bob', domain: 'example.com', display_name: 'ＤＩＧＩＴＡＬ ＣＡＴ', note: 'Software engineer, free time musician and ＤＩＧＩＴＡＬ ＳＰＯＲＴＳ enthusiast. Likes cats. Warning: May contain memes', avatar_remote_url: 'https://quitter.no/avatar/7477-300-20160211190340.png') }

    before do
      stub_request(:post, "https://quitter.no/main/push/hub").to_return(:status => 200, :body => "", :headers => {})
      subject.call(xml, remote_account, true)
    end

    it 'sets new hub url' do
      expect(remote_account.reload.hub_url).to eq 'https://quitter.no/main/push/hub'
    end

    it 're-subscribes to the new hub' do
      expect(stub_request(:post, "https://quitter.no/main/push/hub")).to have_been_made.once
    end
  end
end
