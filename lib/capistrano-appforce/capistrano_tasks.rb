require 'fog'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) : Capistrano.configuration(:must_exist)

configuration.load do
  def create_server type
    case cloud_provider
      when :aws
        @compute = Fog::Compute.new({:provider => "AWS", :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret, :region => aws_region}) 
        server = @compute.servers.create(image_id: aws_image_id, flavor_id: aws_flavor, key_name: aws_key_name, groups: [type, "default", "test"], availability_zone: aws_availability_zone)
        puts "Creating server (#{server.id})"
        server.wait_for { print "."; ready? }
        #TODO: Consider and array for this so we could run on all with the same command in the future
        @server_dns_name = server.dns_name
        @server_id = server.id
        @compute.tags.create(resource_id:server_id, key:"Name", value:"#{stage}_#{type}_#{@server_id}", resource_type:"instance")
        @compute.tags.create(resource_id:server_id, key:"chef_environment", value:"#{stage}", resource_type:"instance")
        @compute.tags.create(resource_id:server_id, key:"server_type", value:"#{type}", resource_type:"instance")
        puts "**************************\nSuccessfully created server #{@server_dns_name} (#{@server_id})\n************************************"
    end
  end

  def boostrap_server type
    #command = %Q(knife bootstrap #{@server_dns_name} -r "role[base], role[#{type}]" -N #{stage}_#{type}_#{@server_id} -i #{aws_identity_file} -x ubuntu --sudo)
    command = %Q(knife bootstrap #{@server_dns_name} -r "role[base], role[#{type}]" -N #{stage}_#{type}_#{@server_id} -x ubuntu --sudo)
    system(command)
  end

  def destroy_last_server type
    case cloud_provider
      when :aws
        system("knife ec2 server delete #{@server_id} --purge -N #{stage}_#{type}_#{@server_id} --region #{aws_region}")
    end
  end

  namespace :cloud do
    task :hello do 
      puts "HELLO CLOUD"
    end

    namespace :create do
      cloud_server_types.each do |type|
        desc "Create a new #{type} server on the cloud"
        task "#{type}".to_sym do 
          create_server "#{type}"
        end
      end
    end

    namespace :bootstrap do 
      cloud_server_types.each do |type|
        desc "Bootstrap Chef on the server and execute the run list for #{type} servers"
        task "#{type}".to_sym do
          boostrap_server type
          on_rollback { destroy_last_server(type) }
        end
      end
    end

    namespace :delete do
      cloud_server_types.each do |type|
        desc "Delete a(n) #{type} server with the given id"
        task "#{type}".to_sym do
          #TODO: Validate user input against a fog list of servers which have the tag for the given server type.
          @server_id = Capistrano::CLI.ui.ask "Please enter the instance id of the application server you wish to destroy"
          #TODO: Create a robust Confirmation set of info about the provided server if the above validation passes, ask "yes/no"
          destroy_last_server "application"
        end
      end
    end
  end

  after "cloud:create:app", "cloud:bootstrap:app" 
end
