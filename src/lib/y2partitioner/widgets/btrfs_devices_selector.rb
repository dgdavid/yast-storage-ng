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
        @controller = controller
        super()

        textdomain "storage"
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
        controller.selected_devices
      end

      # @see Widgets::DevicesSelection#unselected
      def unselected
        controller.available_devices
      end

      # @see Widgets::DevicesSelection#select
      def select(sids)
        filter_devices(unselected, sids).each do |device|
          controller.add_device(device)
        end
      end

      # @see Widgets::DevicesSelection#unselect
      #
      # @note Committed physical volumes cannot be unselected,
      #   see {#check_for_committed_devices}.
      def unselect(sids)
        filter_devices(selected, sids).each do |device|
          controller.remove_device(device)
        end
      end

      def unselected_size
        nil
      end

      def selected_size
        nil
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
        current_errors = errors
        return true if current_errors.none?

        message = current_errors.join("\n\n")
        Yast::Popup.Error(message)

        false
      end

    private

      # @return [Actions::Controllers::LvmVg]
      attr_reader :controller

      def errors
        [
          selected_devices_error,
          metadata_devices_error,
          data_devices_error
        ].compact
      end

      # Validates that at least one physical volume was added to the volume group
      #
      # @note An error popup is shown when no physical volume was added.
      #
      # @return [Boolean]
      def selected_devices_error
        return nil if controller.selected_devices.any?

        # TRANSLATORS: Error message when no device is selected
        _("Select at least one device.")
      end

      def metadata_devices_error
        raid_level_devices_error(:metadata)
      end

      def data_devices_error
        raid_level_devices_error(:data)
      end

      def raid_level_devices_error(data)
        return nil unless filesystem

        allowed_raid_levels = allowed_raid_levels(data)
        selected_raid_level = selected_raid_level(data)

        return nil if allowed_raid_levels.include?(selected_raid_level)

        format(
          _("According to the selected devices, only the following %{data}\n" \
            "RAID levels can be used: %{levels}."),
          data:   data.to_s,
          levels: allowed_raid_levels.map(&:to_human_string).join(", ")
        )
      end

      def allowed_raid_levels(data)
        controller.allowed_raid_levels(data)
      end

      def selected_raid_level(data)
        controller.send("#{data}_raid_level")
      end

      def filesystem
        controller.filesystem
      end

      def filter_devices(devices, sids)
        devices.select { |d| sids.include?(d.sid) }
      end
    end
  end
end
