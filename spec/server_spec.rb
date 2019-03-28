RSpec.describe 'Server' do
  let(:http) { Net::HTTP.new('127.0.0.1', 3000) }
  let(:default_header) { {Authorization: "Bearer #{token}"} }
  let(:token) { 'testtoken' }

  def request(method, path, data: nil, header: {})
    if data
      header['Content-Type'] = 'application/json'
      data = data.to_json unless data.is_a?(String)
    end
    http.send_request(method.upcase, path, data, header.merge(default_header))
  end

  def assert_json_response(data)
    expect(subject).to include('content-type' => ['application/json'])
    expect(JSON.load(subject.body)).to eq(data)
  end

  shared_examples 'authorization' do
    context 'without auth headers' do
      let(:default_header) { {} }
      it do
        should be_instance_of(Net::HTTPUnauthorized)
        assert_json_response('error' => 'Unauthorized')
        expect(subject).to include('www-authenticate' => ['Bearer realm=app'])
      end
    end

    context 'with invalid token' do
      let(:token) { 'invalid' }
      it do
        should be_instance_of(Net::HTTPForbidden)
        assert_json_response('error' => 'Forbidden')
      end
    end
  end

  describe 'GET' do
    subject { request(:get, '/missing') }
    include_examples 'authorization'
    it do
      should be_instance_of(Net::HTTPNotFound)
      assert_json_response('error' => 'Not found')
    end
  end

  describe 'DELETE' do
    subject { request(:delete, '/missing') }
    include_examples 'authorization'
    it { should be_instance_of(Net::HTTPNoContent) }
  end

  describe 'POST' do
    subject { request(:post, '/test_create', data: {test: :value}) }
    include_examples 'authorization'
    it do
      should be_instance_of(Net::HTTPOK)
      assert_json_response({})
    end
  end

  describe 'storing data' do
    let(:key) { '/test-key' }
    let(:other_key) { '/other-key' }
    let(:value) { {some: :value} }
    let(:other_value) { {other: :value2} }
    before { request(:delete, key) && request(:delete, other_key) }

    it 'stores, fetches and deletes values' do
      expect { request(:post, key, data: value) }.
        to change { request(:get, key).class }.from(Net::HTTPNotFound).to(Net::HTTPOK).
        and not_change { request(:get, other_key).class }.from(Net::HTTPNotFound)
      expect(request(:get, key).body).to eq value.to_json

      expect { request(:post, key, data: other_value) }.
        to change { request(:get, key).body }.from(value.to_json).to(other_value.to_json)

      expect { request(:post, other_key, data: value) }.
        to change { request(:get, other_key).body }.to(value.to_json)
      expect { request(:delete, key, data: value) }.
        to change { request(:get, key).class }.from(Net::HTTPOK).to(Net::HTTPNotFound).
        and not_change { request(:get, other_key).body }
    end
  end
end
