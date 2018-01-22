# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
    class LvmVgDevicesSelector < Widgets::DevicesSelection
      # Constructor
      #
      # @param controller [Actions::Controllers::LvmVg]
      def initialize(controller)
        @controller = controller
        super()
      end

      # @see Widgets::DevicesSelection#selected
      def selected
        controller.devices_in_vg
      end

      # @see Widgets::DevicesSelection#selected_size
      def selected_size
        controller.vg_size
      end

      # @see Widgets::DevicesSelection#unselected
      def unselected
        controller.available_devices
      end

      # @see Widgets::DevicesSelection#select
      def select(sids)
        find_by_sid(unselected, sids).each do |device|
          controller.add_device(device)
        end
      end

      # @see Widgets::DevicesSelection#unselect
      #
      # @note Committed physical volumes cannot be unselected, see {#validate_unselect}.
      def unselect(sids)
        validate_unselect(sids)
        sids -= controller.committed_devices.map(&:sid)

        find_by_sid(selected, sids).each do |device|
          controller.remove_device(device)
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
        selected_devices_validation && size_validation
      end

    private

      # @return [Actions::Controllers::LvmVg]
      attr_reader :controller

      # Validates that at least one physical volume was added to the volume group
      #
      # @note An error popup is shown when no physical volume was added.
      #
      # @return [Boolean]
      def selected_devices_validation
        return true if controller.devices_in_vg.size > 0

        Yast::Popup.Error(_("Select at least one device."))
        false
      end

      # Validates that the volume group size is enough for all its logical volumes
      #
      # @note An error popup is shown when the size is not enough.
      #
      # @return [Boolean]
      def size_validation
        return true if controller.vg_size >= controller.lvs_size

        Yast::Popup.Error(
          format(
            _("The volume group size cannot be less than %s."), controller.lvs_size
          )
        )

        false
      end

      # Validates that unselected phyical volumes can be removed
      #
      # @note A physical volume cannot be removed if it is already committed. An error
      #   popup is shown when a committed physical volume is tried to be removed.
      #
      # @see Actions::Controllers::LvmVg#committed_devices
      #
      # @param sids [Array<Integer>]
      # @return [Boolean]
      def validate_unselect(sids)
        committed_devices = controller.committed_devices.select { |d| sids.include?(d.sid) }

        return true if committed_devices.empty?

        error_message = if committed_devices.size > 1
          _("Physical volumes %s cannot be removed because they already exist on disk")
        else
          _("Physical volume %s cannot be removed because it already exists on disk")
        end

        Yast::Popup.Error(format(error_message, committed_devices.map(&:name).join(", ")))

        false
      end

      # Finds devices by sid
      #
      # @param devices [Array<Y2Storage::BlkDevice>]
      # @param sids [Array<Integer>]
      #
      # @return [Array<Y2Storage::BlkDevice>]
      def find_by_sid(devices, sids)
        devices.select { |d| sids.include?(d.sid) }
      end
    end
  end
end
