# Copyright (c) 2012-2018 SoftBank Robotics. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the COPYING file.
import abc
import os

import qisys.sh


class LinguistProject(object):
    """" A LinguistProject has a name, a domain name, and a
    list of linguas. Daughter classes should implement the
    release() and update() methods

    """
    __metaclass__ = abc.ABCMeta

    def __init__(self, name, path, domain=None, linguas=None):
        self.path = path
        self.domain = domain
        self.name = name
        self.linguas = linguas

    @property
    def po_path(self):
        res = os.path.join(self.path, "po")
        qisys.sh.mkdir(res)
        return res

    @property
    def potfiles_in(self):
        res = os.path.join(self.po_path, "POTFILES.in")
        if not os.path.exists(res):
            mess = "No po/POTFILES.in for project {} in {}"
            raise Exception(mess.format(self.name, self.path))
        return res

    def get_sources(self):
        """ Parse po/POTFILES.in and return a list of filenames
        relative to self.path

        """
        res = list()
        with open(self.potfiles_in, "r") as fp:
            for line in fp:
                if line.startswith("#"):
                    continue
                res.append(line.strip())
        return res

    @abc.abstractmethod
    def update(self):
        pass

    @abc.abstractmethod
    def release(self, raises=True):
        pass
