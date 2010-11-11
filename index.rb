require 'sinatra'
require 'erb'
require 'sanitize'
require 'sequel'
require 'net/imap'
require 'resolv'
require 'base64'

enable :sessions
DB = Sequel.mysql 'mail2feed', :user => 'root', :password => '', :host => 'localhost'

get '/' do
    erb :index
end

get '/dashboard' do
  @user = user = User.first(:id => session['user'])
  erb :dashboard
end

=begin
post '/register' do
  user = User.new(:email => params['email'], :password => Base64.encode64(params['password']), :server => params['server'])
  if user.valid?
    user.save
    session['user'] = user.id
    redirect '/dashboard'
  else
    @errors = user.errors
    erb :index
  end
end
=end

get '/login' do
  erb :login
end

post '/login' do
  user = User.first(:email => params['email'], :password => Base64.encode64(params['password']))
  if user
    session['user'] = user.id
    redirect '/dashboard'
  else
    @errors = ['Wrong email or password'] 
    erb :login
  end
end

get '/logout' do
  session['user'] = nil
  redirect '/'
end

get '/feed' do
  user = User.first(:id => params['id'].to_i)
  emails = get_emails(user.email, Base64.decode64(user.password), user.server, true)
  builder do |xml|
    xml.instruct! :xml, :version => '1.0'
    xml.rss :version => "2.0" do
      xml.channel do
        xml.title "Your emails"
        xml.description "There are the messages from your email account"
        xml.link "http://danilat.com/"
        
        emails.each do |email|
          xml.item do
            xml.title email["subject"]
            xml.description Sanitize.clean(email["body"])
            xml.pubDate Time.parse(email["date"].to_s).rfc822()
          end
        end
      end
    end
  end
end


def get_emails(username, password, imap_server, ssl=false)
  emails = []
  imap = Net::IMAP.new(imap_server,993, ssl)
  imap.login(username, password)
  imap.select('INBOX')
  one_month_ago = Date.today - 30
  month = Date::ABBR_MONTHNAMES[one_month_ago.month]
  since = "#{one_month_ago.day}-#{month}-#{one_month_ago.year}"
  imap.search(['SINCE', since]).each do |message_id|
    msg = imap.fetch(message_id, "(ENVELOPE BODY[TEXT])")[0]
    envelope = msg.attr["ENVELOPE"]
    body = msg.attr["BODY[TEXT]"]
    mail = {}
    mail["subject"] = envelope.subject
    mail["from"] = envelope.from[0].name
    mail["date"] = envelope.date
    mail["body"] = msg.attr["BODY[TEXT]"]
    emails << mail
  end
  imap.expunge()
  return emails
end

def imap_address_is_ok?(url, ssl=true)
  begin
    imap = Net::IMAP.new(url,993, ssl)
    return true
  rescue
    return false
  end
end

def validate_email_domain(email)
      domain = email.match(/\@(.+)/)[1]
      Resolv::DNS.open do |dns|
          @mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
      end
      @mx.size > 0 ? true : false
end

class User < Sequel::Model
  def validate
    super
    errors.add(:email, 'cannot be empty') if !email || email.empty?
    errors.add(:password, 'cannot be empty') if !password || password.empty?
    errors.add(:server, 'cannot be empty') if !server || server.empty?
    errors.add(:email, ' address isn\'t valid') if !validate_email_domain(email)
    errors.add(:server, ' address isn\'t valid') if !imap_address_is_ok?(server)
  end
end
