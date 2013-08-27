require 'fog'
require 'yaml'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) : Capistrano.configuration(:must_exist)

configuration.load do

  @appforce = YAML::load(File.open("#{Dir.pwd}/config/appforce.yml"))
  @cloud_provider = @appforce['cloud_providers'][stage]
  @cloud_server_types = @appforce['server_types'].keys

  #find credentials TODO: Swap this for ConfMan implementation
  cloud_options = @appforce['cloud_options']["#{@cloud_provider}_#{stage}"]
  @key = cloud_options['access_key']
  @secret = cloud_options['secret']
  @identity_file = cloud_options['identity_file']
  @identity_file_name = cloud_options['identity_file_name']

  def create_server type
    case @cloud_provider
      when :aws
        opts = server_opts_for(type)
        @compute = Fog::Compute.new({:provider => "AWS", :aws_access_key_id => @key, :aws_secret_access_key => @secret, :region => opts['aws_region']}) 
        server = @compute.servers.create(image_id: opts['image_id'], flavor_id: opts['flavor_id'], key_name: @identity_file_name, groups:opts['security_groups'])
        puts "Creating server (#{server.id})"
        server.wait_for { print "."; ready? }
        
        #TODO: Consider an array for this so we could run on all with the same command in the future
        @server_dns_name = server.dns_name
        @server_id = server.id
        @compute.tags.create(resource_id:@server_id, key:"Name", value:"#{stage}_#{type}_#{@server_id}", resource_type:"instance")
        @compute.tags.create(resource_id:@server_id, key:"chef_environment", value:"#{stage}", resource_type:"instance")
        @compute.tags.create(resource_id:@server_id, key:"server_type", value:"#{type}", resource_type:"instance")
        puts "\n********************************************************************************************************\nSuccessfully created server #{@server_dns_name} (#{@server_id})\n********************************************************************************************************"
    end
  end

  def server_opts_for type
    config = @appforce['server_types'][type]
    stage_config = config[stage]
    config.merge(stage_config)
  end

  def boostrap_server type
    opts = server_opts_for(type)
    command = %Q(knife bootstrap #{@server_dns_name} -r #{opts['run_list']} -N #{stage}_#{type}_#{@server_id} -i #{@identity_file} -x #{opts['user']} --sudo)
    system(command)
  end

  def destroy_last_server type
    case @cloud_provider
      when :aws
        system("knife ec2 server delete #{@server_id} --purge -N #{stage}_#{type}_#{@server_id} --region #{aws_region}")
    end
  end

  ## BEGIN GENERATED TASKS
  namespace :cloud do
    namespace :create do
      @cloud_server_types.each do |type|
        desc "Create a new #{type} server on the cloud"
        task "#{type}".to_sym do 
          create_server "#{type}"
        end
      end
    end

    namespace :bootstrap do 
      @cloud_server_types.each do |type|
        desc "Bootstrap Chef on the server and execute the run list for #{type} servers"
        task "#{type}".to_sym do
          transaction do 
            boostrap_server type
            on_rollback { destroy_last_server(type) }
          end
        end
      
        #Register the bootstrap tasks as after hooks to the create tasks
        after "cloud:create:#{type}", "cloud:bootstrap:#{type}"
      end
    end

    namespace :delete do
      @cloud_server_types.each do |type|
        desc "Delete a(n) #{type} server with the given id"
        task "#{type}".to_sym do
          #TODO: Validate user input against a fog list of servers which have the tag for the given server type.
          @server_id = Capistrano::CLI.ui.ask "Please enter the instance id of the application server you wish to destroy"
          #TODO: Create a robust Confirmation set of info about the provided server if the above validation passes, ask "yes/no"
          destroy_last_server type
        end
      end
    end
  end
end
