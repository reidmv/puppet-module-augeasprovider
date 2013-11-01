# Alternative Augeas-based providers for Puppet
#
# Copyright (c) 2012 Raphaël Pinson
# Licensed under the Apache License, Version 2.0

require File.dirname(__FILE__) + '/../../../augeasproviders/provider'

Puppet::Type.type(:puppet_auth_allow).provide(:augeas) do
  desc "Uses Augeas API to update an allow entry in Puppet's auth.conf."

  include AugeasProviders::Provider

  default_file { '/etc/puppetlabs/puppet/auth.conf' }

  lens { 'Puppet_Auth.lns' }

  confine :feature => :augeas
  confine :exists => target

  resource_path do |resource|
    path  = resource[:path]
    allow = resource[:allow]
    "$target/path[.='#{path}']/allow/*[.='#{allow}']"
  end

  def self.instances
    resources = []
    augopen do |aug|
      settings = aug.match("$target/path")

      settings.each do |pathnode|
        # Set $resource for each
        aug.defvar('resource', pathnode)

        path   = aug.get(pathnode)
        allows = attr_aug_reader_allow(aug)

        # Define a resource for each allow
        allows.each do |allow|
          resources << new(
            :name   => "#{path}: allow #{allow}",
            :ensure => :present,
            :path   => path,
            :allow  => allow
          )
        end
      end
    end
    resources
  end

  def create
    augopen! do |aug|
      aug.defvar('allow', "$target/path[.='#{resource[:path]}']/allow")
      aug.insert("$allow") if aug.match("$allow/*").empty?

      last_allow = aug.match("$allow/*[last()]").last
      last_index = last_allow ? last_allow.split('/').last : '0'
      next_index = (last_index.to_i + 1).to_s

      aug.insert("$allow/*[last()]", next_index, false)
      aug.set("$allow/*[.='']", resource[:allow])
    end
  end

  attr_aug_accessor(:allow,
    :type        => :array,
    :sublabel    => :seq
  )

end
