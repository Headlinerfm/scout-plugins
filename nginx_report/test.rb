require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../nginx_report.rb', __FILE__)

require 'open-uri'
class NginxReportTest < Test::Unit::TestCase
  def setup

  end
  
  def teardown
    FakeWeb.clean_registry    
  end
  
  def test_two_runs
    time = Time.now
    uri="http://127.0.0.1/nginx_status"
    FakeWeb.register_uri(:get, uri, 
      [
       {:body => File.read(File.dirname(__FILE__)+'/fixtures/nginx_status.txt')},
       {:body => File.read(File.dirname(__FILE__)+'/fixtures/nginx_status_second_run.txt')}
      ]
    )
    
    Timecop.travel(time-60) do 
      plugin = NginxReport.new(nil,{},{})
      res = plugin.run
      Timecop.travel(time) do
        plugin = NginxReport.new(nil,res[:memory],{})
        res = plugin.run
        assert count=res[:reports].find { |r| r.keys.include?(:requests_per_sec)}
        assert_in_delta 50/60.to_f, count.values.last, 0.001
      end
    end
  end

  def test_404
    uri="http://127.0.0.1/nginx_status"
    time  = Time.now
    FakeWeb.register_uri(:get, uri, :body => "Not found", :status => ["404","Not Found"])
    
    plugin = NginxReport.new(nil,{},{})
    res = plugin.run
    assert res[:errors].any?
  end


  def test_connection_refused_and_retry_ok
    uri="http://127.0.0.1/nginx_status"
    time  = Time.now
    FakeWeb.register_uri(:get, uri, [{:exception => Errno::ECONNREFUSED},{:body => File.read(File.dirname(__FILE__)+'/fixtures/nginx_status.txt')}])
    
    plugin = NginxReport.new(nil,{},{})
    res = plugin.run
    assert res[:errors].empty?
    assert res[:reports].any?
  end

  # ensure we don't get stuck in a retry loop
  def test_connection_refused_on_retry
    uri="http://127.0.0.1/nginx_status"
    time  = Time.now
    FakeWeb.register_uri(:get, uri, :exception => Errno::ECONNREFUSED)
    plugin = NginxReport.new(nil,{},{})
    assert_raises(Errno::ECONNREFUSED) { plugin.run }
  end
end