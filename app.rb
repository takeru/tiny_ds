require 'sinatra'
require 'lib/tiny_ds'

# Create your model class
class Shout < TinyDS::Base
  property :message,    :text
  property :created_at, :time
  property :updated_at, :time
end

# Make sure our template can use <%=h
helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get '/' do
  # Just list all the shouts
  @shouts = Shout.query.sort(:created_at, :desc).all
  erb :index
end

post '/' do
  # Create a new shout and redirect back to the list.
  shout = Shout.create(:message => params[:message])
  redirect '/'
end

get '/show/:id' do
  @shout = Shout.get_by_id(params[:id])
  erb :show
end
