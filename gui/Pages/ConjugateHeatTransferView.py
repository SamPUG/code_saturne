# -*- coding: iso-8859-1 -*-
#
#-------------------------------------------------------------------------------
#
#     This file is part of the Code_Saturne User Interface, element of the
#     Code_Saturne CFD tool.
#
#     Copyright (C) 1998-2009 EDF S.A., France
#
#     contact: saturne-support@edf.fr
#
#     The Code_Saturne User Interface is free software; you can redistribute it
#     and/or modify it under the terms of the GNU General Public License
#     as published by the Free Software Foundation; either version 2 of
#     the License, or (at your option) any later version.
#
#     The Code_Saturne User Interface is distributed in the hope that it will be
#     useful, but WITHOUT ANY WARRANTY; without even the implied warranty
#     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with the Code_Saturne Kernel; if not, write to the
#     Free Software Foundation, Inc.,
#     51 Franklin St, Fifth Floor,
#     Boston, MA  02110-1301  USA
#
#-------------------------------------------------------------------------------

"""
This module defines the conjugate heat transfer view data management.

This module contains the following classes and function:
- SyrthesAppNumberDelegate
- ProjectionAxisDelegate
- SelectionCriteriaDelegate
- StandardItemModelSyrthes
- ConjugateHeatTransferView
"""

#-------------------------------------------------------------------------------
# Standard modules
#-------------------------------------------------------------------------------

import string
import logging

#-------------------------------------------------------------------------------
# Third-party modules
#-------------------------------------------------------------------------------

from PyQt4.QtCore import *
from PyQt4.QtGui  import *

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from Base.Common import LABEL_LENGTH_MAX
from Base.Toolbox import GuiParam
from ConjugateHeatTransferForm import Ui_ConjugateHeatTransferForm
from Base.QtPage import IntValidator, DoubleValidator, RegExpValidator, ComboModel
from Pages.ConjugateHeatTransferModel import ConjugateHeatTransferModel

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("ConjugateHeatTransferView")
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# QLineEdit delegate for validation of Syrthes app number
#-------------------------------------------------------------------------------

class SyrthesAppNumberDelegate(QItemDelegate):
    def __init__(self, parent = None):
        super(SyrthesAppNumberDelegate, self).__init__(parent)
        self.parent = parent


    def createEditor(self, parent, option, index):
        editor = QLineEdit(parent)
        validator = IntValidator(editor, min=0)
        editor.setValidator(validator)
        editor.installEventFilter(self)
        return editor


    def setEditorData(self, editor, index):
        value = index.model().data(index, Qt.DisplayRole).toString()
        editor.setText(value)


    def setModelData(self, editor, model, index):
        value, ok = editor.text().toInt()
        if editor.validator().state == QValidator.Acceptable:
            model.setData(index, QVariant(value), Qt.DisplayRole)

#-------------------------------------------------------------------------------
# QComboBox delegate for Axis Projection in Conjugate Heat Transfer table
#-------------------------------------------------------------------------------

class ProjectionAxisDelegate(QItemDelegate):
    """
    Use of a combo box in the table.
    """
    def __init__(self, parent = None):
        super(ProjectionAxisDelegate, self).__init__(parent)
        self.parent = parent


    def createEditor(self, parent, option, index):
        editor = QComboBox(parent)
        editor.addItem(QString("off"))
        editor.addItem(QString("X"))
        editor.addItem(QString("Y"))
        editor.addItem(QString("Z"))
        editor.installEventFilter(self)
        return editor


    def setEditorData(self, comboBox, index):
        row = index.row()
        col = index.column()
        string = index.model().dataSyrthes[row][col]
        comboBox.setEditText(string)


    def setModelData(self, comboBox, model, index):
        value = comboBox.currentText()
        model.setData(index, QVariant(value), Qt.DisplayRole)

#-------------------------------------------------------------------------------
# QLineEdit delegate for location
#-------------------------------------------------------------------------------

class SelectionCriteriaDelegate(QItemDelegate):
    def __init__(self, parent, mdl):
        super(SelectionCriteriaDelegate, self).__init__(parent)
        self.parent = parent
        self.__model = mdl


    def createEditor(self, parent, option, index):
        editor = QLineEdit(parent)
        return editor


    def setEditorData(self, editor, index):
        self.value = index.model().data(index, Qt.DisplayRole).toString()
        editor.setText(self.value)


    def setModelData(self, editor, model, index):
        value = editor.text()

#        if value != self.value and str(value) in self.__model.getLocalizationsZonesList():
#            title = self.tr("Warning")
#            msg   = self.tr("This localization is already used.\n"\
#                            "Please give another one.")
#            QMessageBox.information(self.parent, title, msg)
#            return

        if str(value) != "" :
            model.setData(index, QVariant(value), Qt.DisplayRole)

#-------------------------------------------------------------------------------
# StandarItemModel class
#-------------------------------------------------------------------------------

class StandardItemModelSyrthes(QStandardItemModel):

    def __init__(self, model):
        """
        """
        QStandardItemModel.__init__(self)
        self.setColumnCount(4)
        self.headers = [self.tr("Instance name"),
                        self.tr("Application number"),
                        self.tr("Projection Axis"),
                        self.tr("Selection criteria")]
        self.setColumnCount(len(self.headers))
        self.dataSyrthes = []
        self.__model = model


    def data(self, index, role):
        if not index.isValid():
            return QVariant()
        if role == Qt.DisplayRole:
            return QVariant(self.dataSyrthes[index.row()][index.column()])
        elif role == Qt.TextAlignmentRole:
            return QVariant(Qt.AlignCenter)
        return QVariant()


    def flags(self, index):
        if not index.isValid():
            return Qt.ItemIsEnabled
        return Qt.ItemIsEnabled | Qt.ItemIsSelectable | Qt.ItemIsEditable


    def headerData(self, section, orientation, role):
        if orientation == Qt.Horizontal and role == Qt.DisplayRole:
            return QVariant(self.headers[section])
        return QVariant()


    def setData(self, index, value, role):
        if not index.isValid():
            return QVariant()

        row = index.row()
        if index.column() in (0, 2, 3):
            self.dataSyrthes[row][index.column()] = str(value.toString())
        else:
            self.dataSyrthes[row][index.column()], ok = value.toInt()

        num = row + 1
        self.__model.setSyrthesInstanceName(num, self.dataSyrthes[row][0])
        self.__model.setSyrthesAppNumber(num, self.dataSyrthes[row][1])
        self.__model.setSyrthesProjectionAxis(num, self.dataSyrthes[row][2])
        self.__model.setSelectionCriteria(num, self.dataSyrthes[row][3])
        
        id1 = self.index(0, 0)
        id2 = self.index(self.rowCount(), 0)
        self.emit(SIGNAL("dataChanged(const QModelIndex &, const QModelIndex &)"), id1, id2)
        return True


    def addItem(self, syrthes_name, app_num, proj_axis, location):
        """
        Add a row in the table.
        """
        self.dataSyrthes.append([syrthes_name, app_num, proj_axis, location])
        row = self.rowCount()
        self.setRowCount(row+1)


    def deleteRow(self, row):
        """
        Delete the row in the model
        """
        del self.dataSyrthes[row]
        row = self.rowCount()
        self.setRowCount(row-1)

#-------------------------------------------------------------------------------
# Main class
#-------------------------------------------------------------------------------

class ConjugateHeatTransferView(QWidget, Ui_ConjugateHeatTransferForm):
    """
    """
    def __init__(self, parent, case):
        """
        Constructor
        """
        QWidget.__init__(self, parent)

        Ui_ConjugateHeatTransferForm.__init__(self)
        self.setupUi(self)

        self.__case = case
        self.__model = ConjugateHeatTransferModel(self.__case)

        # Models
        self.modelSyrthes = StandardItemModelSyrthes(self.__model)
        self.tableViewSyrthes.setModel(self.modelSyrthes)

        self.tableViewSyrthes.verticalHeader().setResizeMode(QHeaderView.ResizeToContents)
        self.tableViewSyrthes.horizontalHeader().setResizeMode(QHeaderView.ResizeToContents)
        self.tableViewSyrthes.horizontalHeader().setResizeMode(3, QHeaderView.Stretch)

        delegateSyrthesAppNum = SyrthesAppNumberDelegate(self.tableViewSyrthes)
        self.tableViewSyrthes.setItemDelegateForColumn(1, delegateSyrthesAppNum)
        delegateProjectionAxis = ProjectionAxisDelegate(self.tableViewSyrthes)
        self.tableViewSyrthes.setItemDelegateForColumn(2, delegateProjectionAxis)
        delegateSelectionCriteria = SelectionCriteriaDelegate(self.tableViewSyrthes, self.__model)
        self.tableViewSyrthes.setItemDelegateForColumn(3, delegateSelectionCriteria)

        # Connections
        self.connect(self.pushButtonAdd,    SIGNAL("clicked()"), self.slotAddSyrthes)
        self.connect(self.pushButtonDelete, SIGNAL("clicked()"), self.slotDeleteSyrthes)

        # Insert list of Syrthes coupling for view
        for c in self.__model.getSyrthesCouplingList():
            [syrthes_name, app_num, proj_axis, location] = c
            self.modelSyrthes.addItem(syrthes_name, app_num, proj_axis, location)

        #FIXME:
        self.tableViewSyrthes.hideColumn(0)
        self.tableViewSyrthes.hideColumn(1)
        self.__pushButtonAddUpdate()


    def __pushButtonAddUpdate(self):
        """
        Temporay function.
        """
        #FIXME:
        if len(self.__model.getSyrthesCouplingList()) >= 1:
            self.pushButtonAdd.setEnabled(False)
        else:
            self.pushButtonAdd.setEnabled(True)


    @pyqtSignature("")
    def slotAddSyrthes(self):
        """
        Set in view label and variables to see on profile
        """
        syrthes_name = self.__model.defaultValues()['syrthes_name']
        app_num      = self.__model.defaultValues()['syrthes_app_num']
        proj_axis    = self.__model.defaultValues()['projection_axis']
        location     = self.__model.defaultValues()['selection_criteria']
        num = self.__model.addSyrthesCoupling(syrthes_name, app_num, proj_axis, location)
        self.modelSyrthes.addItem(syrthes_name, app_num, proj_axis, location)
        self.__pushButtonAddUpdate()


    @pyqtSignature("")
    def slotDeleteSyrthes(self):
        """
        Delete the profile from the list (one by one).
        """
        row = self.tableViewSyrthes.currentIndex().row()
        log.debug("slotDeleteSyrthes -> %s" % (row,))
        if row == -1:
            title = self.tr("Warning")
            msg   = self.tr("You must select an existing coupling")
            QMessageBox.information(self, title, msg)
        else:
            self.modelSyrthes.deleteRow(row)
            self.__model.deleteSyrthesCoupling(row+1)
        self.__pushButtonAddUpdate()


    def tr(self, text):
        """
        Translation
        """
        return text

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
