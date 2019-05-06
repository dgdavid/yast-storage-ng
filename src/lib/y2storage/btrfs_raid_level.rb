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

require "storage"
require "y2storage/storage_enum_wrapper"

module Y2Storage
  # Class to represent all the possible MD parities
  #
  # This is a wrapper for the Storage::MdParity enum
  class BtrfsRaidLevel
    include StorageEnumWrapper

    wrap_enum "BtrfsRaidLevel"

    # Returns human readable representation of enum which is already translated.
    # @return [String]
    # @raise [RuntimeError] when called on enum value for which translation is not yet defined.
    def to_human_string
      Storage::btrfs_raid_level_name(self.to_storage_value)
    end
  end
end
