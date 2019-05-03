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
require "y2storage"
require "y2partitioner/device_graphs"
require "y2partitioner/ui_state"
require "y2partitioner/blk_device_restorer"
require "y2partitioner/actions/controllers/available_devices"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about an LVM volume group being created or
      # modified and takes care of updating the devicegraph when needed.
      class BtrfsDevices
        include Yast::I18n

        include AvailableDevices

        attr_reader :filesystem

        attr_reader :wizard_title

        # Constructor
        #
        # @note When the volume group is not given, a new LvmVg object will be created in
        #   the devicegraph right away.
        #
        # @see #initialize_action
        #
        # @param vg [Y2Storage::LvmVg] a volume group to be modified
        def initialize(filesystem: nil, wizard_title: "")
          textdomain "storage"

          @wizard_title = wizard_title
          @metadata_raid_level = Y2Storage::BtrfsRaidLevel::DEFAULT
          @data_raid_level = Y2Storage::BtrfsRaidLevel::DEFAULT

          @filesystem = filesystem

          UIState.instance.select_row(filesystem) if filesystem
        end

        def raid_levels
          [
            Y2Storage::BtrfsRaidLevel::DEFAULT,
            Y2Storage::BtrfsRaidLevel::SINGLE,
            Y2Storage::BtrfsRaidLevel::DUP,
            Y2Storage::BtrfsRaidLevel::RAID0,
            Y2Storage::BtrfsRaidLevel::RAID1,
            Y2Storage::BtrfsRaidLevel::RAID10
          ]
        end

        def metadata_raid_level
          return @metadata_raid_level unless filesystem

          filesystem.metadata_raid_level
        end

        def metadata_raid_level=(value)
          if filesystem
            filesystem.metadata_raid_level = value
          else
            @metadata_raid_level = value
          end
        end

        def data_raid_level
          return @data_raid_level unless filesystem

          filesystem.data_raid_level
        end

        def data_raid_level=(value)
          if filesystem
            filesystem.data_raid_level = value
          else
            @data_raid_level = value
          end
        end

        # Devices that can be selected to become physical volume of a volume group
        #
        # @note A physical volume could be created using a partition, disk, multipath,
        #   DM Raid or MD Raid. Dasd devices cannot be used.
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def available_devices
          super(current_graph) { |d| valid_device?(d) }
        end

        # Devices that are already used as physical volume by the volume group
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def selected_devices
          return [] unless filesystem

          filesystem.blk_devices
        end

        # Adds a device as physical volume of the volume group
        #
        # It removes any previous children (like filesystems) from the device and
        # adapts the partition id if possible.
        #
        # @raise [ArgumentError] if the device is already an physcial volume of the
        #   volume group.
        #
        # @param device [Y2Storage::BlkDevice]
        def add_device(device)
          device = device.encryption if device.encrypted?
          device.remove_descendants

          if filesystem.nil?
            create_filesystem(device)
          else
            filesystem.add_device(device)
          end
        end

        # Removes a device from the physical volumes of the volume group
        #
        # @raise [ArgumentError] if the device is not a physical volume of the volume group
        #
        # @param device [Y2Storage::BlkDevice]
        def remove_device(device)
          device = device.encryption if device.encryption
          filesystem.remove_device(device)
          BlkDeviceRestorer.new(device.plain_device).restore_from_checkpoint
        end

      private

        def current_graph
          DeviceGraphs.instance.current
        end

        def valid_device?(device)
          !device.is?(:encryption) && !selected_device?(device)
        end

        def selected_device?(device)
          selected_devices.include?(device)
        end

        def create_filesystem(device)
          filesystem = device.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
          filesystem.metadata_raid_level = @metadata_raid_level
          filesystem.data_raid_level = @data_raid_level

          UIState.instance.select_row(filesystem)

          @filesystem = filesystem
        end

        # # Probed version of the current volume group
        # #
        # # @note It returns nil if the volume group does not exist in probed devicegraph.
        # #
        # # @return [Y2Storage::LvmVg, nil]
        # def probed_vg
        #   system = Y2Partitioner::DeviceGraphs.instance.system
        #   system.find_device(vg.sid)
        # end

        # # Whether the current volume group exists in the probed devicegraph
        # #
        # # @return [Boolean] true if the volume group exists in probed; false otherwise.
        # def probed_vg?
        #   !probed_vg.nil?
        # end
      end
    end
  end
end
