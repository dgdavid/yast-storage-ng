# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/actions/transaction_wizard"
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/actions/controllers/btrfs_devices"
require "y2partitioner/dialogs/btrfs_devices"
require "y2partitioner/dialogs/btrfs_options"

Yast.import "Popup"

module Y2Partitioner
  module Actions
    class AddBtrfs < TransactionWizard
      def initialize
        super

        textdomain "storage"
      end

      def devices
        result = Dialogs::BtrfsDevices.run(controller)
        # controller.apply_default_options if result == :next
        # result
      end

      def options
        fs_controller = Controllers::Filesystem.new(controller.filesystem, title)

        Dialogs::BtrfsOptions.run(fs_controller)
      end

    protected

      attr_reader :controller

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start" => "devices",
          "devices"  => { next: "options" },
          "options"  => { next: :finish }
        }
      end

      # @see TransactionWizard
      def init_transaction
        # The controller object must be created within the transaction
        @controller = Controllers::BtrfsDevices.new(wizard_title: title)
      end

      def title
        _("Add Btrfs")
      end

      # @see TransactionWizard
      # def run?
      #   return true unless controller.available_devices.size < 2

      #   Yast::Popup.Error(
      #     _("There are not enough suitable unused devices to create a RAID.")
      #   )
      #   false
      # end
    end
  end
end
