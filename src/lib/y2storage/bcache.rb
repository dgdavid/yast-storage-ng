# encoding: utf-8

# Copyright (c) [2018-2019] SUSE LLC
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

require "y2storage/storage_class_wrapper"
require "y2storage/partitionable"

module Y2Storage
  # A Bcache device
  #
  # A Bcache device can use a backing device to store the data (see BackedBcache)
  # or it can be directly created over a caching set (see FlashBcache).
  #
  # This is a wrapper for Storage::Bcache
  class Bcache < Partitionable
    wrap_class Storage::Bcache, downcast_to: ["BackedBcache", "FlashBcache"]

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Bcache>] all the bcache devices in the given devicegraph,
    #     in no particular order
    storage_class_forward :all, as: "Bcache"

    # @!method self.find_by_name(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String] kernel-style device name (e.g. "/dev/bcache0")
    #   @return [Bcache] nil if there is no such device
    storage_class_forward :find_by_name, as: "Bcache"

    # @!method self.find_free_name(devicegraph)
    #   Returns available free name for bcache device.
    #   @param devicegraph [Devicegraph] in which search for free name
    #   @return [String] full path to new bcache device like "/dev/bcache3"
    storage_class_forward :find_free_name

  protected

    def types_for_is
      super << :bcache
    end
  end
end
