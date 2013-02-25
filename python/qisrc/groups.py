import os

import xml.etree.ElementTree as etree

import qisys.qixml

from qisys import ui

class Groups(object):
    def __init__(self):
        self.groups = dict()

    def projects(self, group_name):
        return self.subgroups_group(group_name)

    def subgroups_group(self, group_name, projects=None):
        if projects is None:
            projects = list()

        group = self.groups.get(group_name)
        if group is None:
            ui.debug(ui.green, group_name, ui.reset, "is not a known group.")
            return projects

        projects.extend(group.projects)

        for subgroup in group.subgroups:
            self.subgroups_group(subgroup, projects=projects)

        return projects

class GroupsParser(qisys.qixml.XMLParser):
    def __init__(self, target):
        super(GroupsParser, self).__init__(target)

    def _parse_group(self, element):
        group_name = element.attrib['name']
        group = Group(group_name)
        parser = GroupParser(group)
        parser.parse(element)
        self.target.groups[group.name] = group



class Group(object):
    def __init__(self, name):
        self.name = name
        self.subgroups = list()
        self.projects = list()

class GroupParser(qisys.qixml.XMLParser):
    def __init__(self, target):
        super(GroupParser, self).__init__(target)

    def _parse_project(self, element):
        self.target.projects.append(element.attrib['name'])

    def _parse_group(self, element):
        self.target.subgroups.append(element.attrib['name'])

def get_root(worktree):
    file = os.path.join(worktree.root, ".qi", "groups.xml")
    if not os.path.exists(file):
        return None
    tree = etree.parse(file)
    return tree.getroot()

def get_groups(worktree):
    root = get_root(worktree)
    if root is None:
        return None
    groups = Groups(root)
    groups.parse()
    return groups
