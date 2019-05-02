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
require "y2partitioner/size_parser"
require "y2partitioner/ui_state"
require "y2partitioner/blk_device_restorer"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about an LVM volume group being created or
      # modified and takes care of updating the devicegraph when needed.
      class BtrfsDevices
        include Yast::I18n

        # @return [String] given volume group name
        attr_accessor :data_raid_level

        attr_accessor :metadata_raid_level

        # Constructor
        #
        # @note When the volume group is not given, a new LvmVg object will be created in
        #   the devicegraph right away.
        #
        # @see #initialize_action
        #
        # @param vg [Y2Storage::LvmVg] a volume group to be modified
        def initialize(filesystem: nil, title: "")
          textdomain "storage"

          initialize_action(vg)
        end

        # Title to display in the dialogs during the process
        #
        # @note The returned title depends on the action to perform (see {#initialize_action})
        #
        # @return [String]
        def wizard_title
          title
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

          if filesystem.nil?
            create_filesystem(device)
          else
            device.remove_descendants
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
          vg.remove_lvm_pv(device)
          BlkDeviceRestorer.new(device.plain_device).restore_from_checkpoint
        end

      private

        # Current action to perform
        # @return [Symbol] :add, :resize
        attr_reader :action

        # Sets the action to perform and initializes necessary data
        #
        # @param current_vg [Y2Storage::LvmVg, nil] nil if the volume group is
        #   going to be created.
        def initialize_action(current_vg)
          detect_action(current_vg)

          case action
          when :add
            initialize_for_add
          when :resize
            initialize_for_resize(current_vg)
          end

          UIState.instance.select_row(vg) unless vg.nil?
        end

        # Detects current action
        #
        # @note When no volume group is given, the action is set to :add. Otherwise,
        #   the action is set to :resize.
        def detect_action(vg)
          # A volume group is given when it is going to be resized
          @action = vg.nil? ? :add : :resize
        end

        # Initializes internal values for add action
        def initialize_for_add
          @vg = create_vg
          @extent_size = DEFAULT_EXTENT_SIZE
          @vg_name = DEFAULT_VG_NAME
        end

        # Initializes internal values for resize action
        def initialize_for_resize(vg)
          @vg = vg
        end

        # Current devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def current_graph
          DeviceGraphs.instance.current
        end

        # Creates a new volume group
        #
        # @return [Y2Storage::LvmVg]
        def create_vg
          Y2Storage::LvmVg.create(working_graph, "")
        end

        # Probed version of the current volume group
        #
        # @note It returns nil if the volume group does not exist in probed devicegraph.
        #
        # @return [Y2Storage::LvmVg, nil]
        def probed_vg
          system = Y2Partitioner::DeviceGraphs.instance.system
          system.find_device(vg.sid)
        end

        # Whether the current volume group exists in the probed devicegraph
        #
        # @return [Boolean] true if the volume group exists in probed; false otherwise.
        def probed_vg?
          !probed_vg.nil?
        end
      end
    end
  end
end
