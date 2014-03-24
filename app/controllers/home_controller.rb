class HomeController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    cache_for 60

    @listings = query :home
  end

  def join

    if params[:email].present? && params[:email] =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
      client  = ConstantContact::Api.new ENV['API_CC_KEY']
      
      contact = { }
      contact['email_addresses'] = [ { 'email_address' => params[:email]} ]
      contact['addresses'] = []
      contact['lists'] = [ { 'id' => '2' } ]

      contact = ConstantContact::Components::Contact.create(contact)

      # add the contact
      begin
        client.add_contact ENV['API_CC_TOKEN'], contact

      rescue
      end
    end

    redirect_to request.referer
  end

end
