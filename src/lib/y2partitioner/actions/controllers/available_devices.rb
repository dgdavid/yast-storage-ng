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

module Y2Partitioner
  module Actions
    module Controllers
      module AvailableDevices
        def available_devices(devicegraph, &block)
          finder = Finder.new(devicegraph)

          finder.available_devices(&block)
        end

        class Finder
          def initialize(devicegraph)
            @devicegraph = devicegraph
          end

          def available_devices(&block)
            devices = all_devices.select { |d| available_device?(d) }

            return devices unless block_given?

            devices.select { |d| block.call(d) }
          end

        private

          attr_reader :devicegraph

          def all_devices
            devicegraph.blk_devices
          end

          def available_device?(device)
            !used?(device) &&
              !formatted_and_mounted?(device) &&
              !partitions?(device) &&
              !extended_partition?(device) &&
              !zero_size?(device)
          end

          # Whether the device is already in use (e.g., as LVM PV or raid disk)
          #
          # @param device [Y2Storage::BlkDevice]
          # @return [Boolean]
          def used?(device)
            device.component_of.any?
          end

          # Whether the device is formatted and mounted
          #
          # @param device [Y2Storage::BlkDevice]
          # @return [Boolean]
          def formatted_and_mounted?(device)
            device.formatted? && device.filesystem.mount_point
          end

          # Whether the device has partitions
          #
          # @param device [Y2Storage::BlkDevice]
          # @return [Boolean]
          def partitions?(device)
            device.respond_to?(:partitions) && device.partitions.any?
          end

          # Whether the device is an extended partition
          #
          # @param device [Y2Storage::BlkDevice]
          # @return [Boolean]
          def extended_partition?(device)
            device.is?(:partition) && device.type.is?(:extended)
          end

          def zero_size?(device)
            device.size.zero?
          end
        end
      end
    end
  end
end
