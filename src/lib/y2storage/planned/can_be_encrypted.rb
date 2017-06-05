#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015-2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2storage/secret_attributes"

module Y2Storage
  module Planned
    # Mixing for planned devices that can have an encryption layer on top.
    # @see Planned::Device
    module CanBeEncrypted
      include SecretAttributes

      # @!attribute encryption_password
      #   @return [String, nil] password used to encrypt the device. If is nil,
      #     it means the device will not be encrypted
      secret_attr :encryption_password

      # Initializations of the mixin, to be called from the class constructor.
      def initialize_can_be_encrypted
      end

      # Checks whether the resulting device must be encrypted
      #
      # @return [Boolean]
      def encrypt?
        !encryption_password.nil?
      end
    end
  end
end