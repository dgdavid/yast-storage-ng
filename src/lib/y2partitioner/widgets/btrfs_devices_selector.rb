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
require "y2partitioner/widgets/devices_selection"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Widget making possible to add and remove physical volumes to a LVM volume group
    class BtrfsDevicesSelector < Widgets::DevicesSelection
      # Constructor
      #
      # @param controller [Actions::Controllers::LvmVg]
      def initialize(controller)
        super()

        textdomain "storage"

        @controller = controller
      end

      def help
        help_for_available_devices + help_for_selected_devices
      end

      def help_for_available_devices
        _("<p><b>Available Devices:</b> " \
          "A list of available LVM physical volumes. " \
          "If this list is empty, you need to create partitions " \
          "as \"Raw Volume (unformatted)\" with partition ID \"Linux LVM\"" \
          "in the \"Hard Disks\" view of the partitioner." \
          "</p>")
      end

      def help_for_selected_devices
        _("<p><b>Selected Devices:</b> " \
          "The physical volumes to create this volume group from. " \
          "If needed, you can always add more physical volumes later." \
          "</p>")
      end

      # @see Widgets::DevicesSelection#selected
      def selected
        controller.btrfs_devices
      end

      # @see Widgets::DevicesSelection#unselected
      def unselected
        controller.available_devices
      end

      # @see Widgets::DevicesSelection#select
      def select(sids)
        filter_devices(unselected, sids).each do |device|
          controller.add_btrfs_device(device)
        end
      end

      # @see Widgets::DevicesSelection#unselect
      #
      # @note Committed physical volumes cannot be unselected,
      #   see {#check_for_committed_devices}.
      def unselect(sids)
        filter_devices(selected, sids).each do |device|
          controller.remove_btrfs_device(device)
        end
      end

      # Validates the selected physical volumes
      # @macro seeAbstractWidget
      #
      # @see #selected_devices_validation
      # @see #size_validation
      #
      # @note An error popup is shown when there is some error in selected devices.
      #
      # @return [Boolean]
      def validate
        errors = errors
        return true if errors.none?

        message = errors.join("\n\n")
        Yast::Popup.Error(message)

        false
      end

    private

      # @return [Actions::Controllers::LvmVg]
      attr_reader :controller

      def errors
        [selected_devices_error].compact
      end

      # Validates that at least one physical volume was added to the volume group
      #
      # @note An error popup is shown when no physical volume was added.
      #
      # @return [Boolean]
      def selected_devices_error
        return nil if controller.btrfs_devices.any?

        # TRANSLATORS: Error message when no device is selected
        _("Select at least one device.")
      end

      def filter_devices(devices, sids)
        devices.select { |d| sids.include?(d.sid) }
      end
    end
  end
end
