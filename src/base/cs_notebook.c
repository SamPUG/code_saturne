/*============================================================================
 * Notebook management.
 *============================================================================*/

/*
  This file is part of Code_Saturne, a general-purpose CFD tool.

  Copyright (C) 1998-2019 EDF S.A.

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation; either version 2 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
  Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

/*----------------------------------------------------------------------------*/

#include "cs_defs.h"

/*----------------------------------------------------------------------------*/

/*----------------------------------------------------------------------------
 * Standard C library headers
 *----------------------------------------------------------------------------*/

#include <assert.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*----------------------------------------------------------------------------
 * Local headers
 *----------------------------------------------------------------------------*/

#include "bft_error.h"
#include "bft_mem.h"
#include "bft_printf.h"

#include "cs_gui_util.h"
#include "cs_log.h"
#include "cs_map.h"
#include "cs_parameters.h"

/*----------------------------------------------------------------------------
 * Header for the current file
 *----------------------------------------------------------------------------*/

#include "cs_notebook.h"

BEGIN_C_DECLS

/*! \cond DOXYGEN_SHOULD_SKIP_THIS */

/*=============================================================================
 * Additional doxygen documentation
 *============================================================================*/

#define _CS_NOTEBOOK_ENTRY_S_ALLOC_SIZE       16

/*============================================================================
 * Structure definition
 *============================================================================*/

typedef struct {

  const char *name;       /* Name of the notebook entry */

  char       *description; /* Description */

  int         id;         /* Entry id */

  cs_real_t   val;        /* Value of the entry */

  int         uncertain; /* Is is an uncertain variable ?
                             0: No
                             1: Yes, as input
                             2: Yes, as output */

  bool        editable;   /* Can the value be modified */

} _cs_notebook_entry_t;

/*============================================================================
 * Static global variables
 *============================================================================*/

static int _n_entries           = 0;
static int _n_entries_max       = 0;
static int _n_uncertain_inputs  = 0;
static int _n_uncertain_outputs = 0;

static _cs_notebook_entry_t **_entries = NULL;

static cs_map_name_to_id_t *_entry_map = NULL;

/*============================================================================
 * Local functions
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief Get a notebook entry by its name.
 *
 * Reruns the cs_notebook_entry_t object for a given name.
 * If it does not exist, bft_error is called.
 *
 * \param[in] name  notebook entry name
 *
 * \return _cs_notebook_entry_t pointer
 */
/*----------------------------------------------------------------------------*/

static _cs_notebook_entry_t *
cs_notebook_entry_by_name(const char *name)
{
  int id = cs_map_name_to_id_try(_entry_map, name);

  if (id > -1)
    return _entries[id];
  else {
    bft_error(__FILE__, __LINE__, 0,
              _("Entry \"%s\" is not defined."), name);
    return NULL;
  }
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief create a notebook entry
 *
 * Creates an entry in the notebook structure based on what the user provided
 * in the GUI.
 *
 * \param[in] name       name of the entry
 * \param[in] uncertain  flag (int) indicating if it is an uncertain input/output
 * \param[in] editable   flag (bool) indicating if the value can be modified
 *
 * \return a _cs_notebook_entry_t pointer
 */
/*----------------------------------------------------------------------------*/

static _cs_notebook_entry_t *
_entry_create(const char  *name,
              int          uncertain,
              bool         editable)
{
  size_t l = strlen(name);
  const char *addr_0 = NULL, *addr_1 = NULL;

  /* Check that the name is not allready used */
  int id = cs_map_name_to_id_try(_entry_map, name);
  if (id > -1)
    bft_error(__FILE__, __LINE__, 0,
              _("Error creating entry:\n"
                "  name:        \"%s\"\n\n"
                "An entry with that name has allready been defined:\n"
                "  id: %d\n"),
              name, id);

  /* Initialize the map is necessary */
  if (_entry_map == NULL)
    _entry_map = cs_map_name_to_id_create();

  else
    addr_0 = cs_map_name_to_id_reverse(_entry_map, 0);

  if (l == 0)
    bft_error(__FILE__, __LINE__, 0, _("Defining an entry requires a name."));

  /* Insert the entry in map */
  int entry_id = cs_map_name_to_id(_entry_map, name);

  /* Move name pointers of previous entries if necessary */
  addr_1 = cs_map_name_to_id_reverse(_entry_map, 0);

  if (addr_1 != addr_0) {
    int i;
    ptrdiff_t addr_shift = addr_1 - addr_0;
    for (i = 0; i < entry_id; i++)
      _entries[i]->name += addr_shift;
  }

  if (entry_id == _n_entries)
    _n_entries = entry_id + 1;

  /* Reallocate entries pointer if necessary */
  if (_n_entries > _n_entries_max) {
    if (_n_entries_max == 0)
      _n_entries_max = 8;
    else
      _n_entries_max *= 2;
    BFT_REALLOC(_entries, _n_entries_max, _cs_notebook_entry_t *);
  }

  /* Allocate entries descriptor block if necessary (same as for cs_field_t) */
  int shift_in_alloc_block = entry_id % _CS_NOTEBOOK_ENTRY_S_ALLOC_SIZE;
  if (shift_in_alloc_block == 0)
    BFT_MALLOC(_entries[entry_id],
               _CS_NOTEBOOK_ENTRY_S_ALLOC_SIZE,
               _cs_notebook_entry_t);

  else
    _entries[entry_id] = _entries[entry_id - shift_in_alloc_block]
                       + shift_in_alloc_block;

  /* Assign the entry */
  _cs_notebook_entry_t *e = _entries[entry_id];

  e->name = cs_map_name_to_id_reverse(_entry_map, entry_id);

  e->id = entry_id;

  e->val = 0.;

  e->uncertain = uncertain;
  if (uncertain == 0)
    _n_uncertain_inputs += 1;
  else if (uncertain == 1)
    _n_uncertain_outputs += 1;

  e->editable  = editable;

  return e;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Set the entry description
 *
 * Set the description of the notebook parameter.
 *
 * \param[in] e            pointer to _cs_notebook_entry_t
 * \param[in] description  description of the entry
 *
 */
/*----------------------------------------------------------------------------*/

static void
_entry_set_description(_cs_notebook_entry_t *e,
                       const char           *description)
{

  int l = strlen(description);
  BFT_MALLOC(e->description, l+1, char);
  if (l == 0)
    strcpy(e->description, "");
  else
    strcpy(e->description, description);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Set the entry value
 *
 * Set the value of the notebook parameter.
 *
 * \param[in] e      pointer to _cs_notebook_entry_t
 * \param[in] value  value to set to the entry
 *
 */
/*----------------------------------------------------------------------------*/

static void
_entry_set_value(_cs_notebook_entry_t *e,
                 cs_real_t             value)
{
  e->val = value;
}

/*! (DOXYGEN_SHOULD_SKIP_THIS) \endcond */

/*============================================================================
 * Public function definitions
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief Output the notebook info to the setup log.
 */
/*----------------------------------------------------------------------------*/

void
cs_notebook_log(void)
{
  if (_n_entries == 0)
    return;

  cs_log_t l = CS_LOG_SETUP;

  cs_log_printf(l, _("Notebook:\n"
                     "---------\n"));
  for (int i = 0; i < _n_entries; i++)
    cs_log_printf(l, _("\n"
                       "  Entry #%d\n"
                       "    name:         %s\n"
                       "    description:  %s\n"
                       "    uncertain:    %d\n"
                       "    editable:     %d\n"
                       "    value:        %f\n"),
                  i,
                  _entries[i]->name,
                  _entries[i]->description,
                  _entries[i]->uncertain,
                  _entries[i]->editable,
                  _entries[i]->val);

  cs_log_printf(l, "\n");
  cs_log_separator(l);
}

/*----------------------------------------------------------------------------*/
/*!
 *  \brief Initialize the notebook object (based on cs_tree_node_t)
 *
 *  The name used to identify the object is "cs_notebook".
 *
 */
/*----------------------------------------------------------------------------*/

void
cs_notebook_load_from_file(void)
{
  const char na[] = "NA";

  cs_tree_node_t *tnb = cs_tree_get_node(cs_glob_tree,
                                         "physical_properties/notebook");
  for (cs_tree_node_t *n = cs_tree_find_node(tnb, "var");
       n != NULL;
       n = cs_tree_node_get_next_of_name(n)) {

    const char *name   = cs_tree_node_get_tag(n, "name");
    const char *oturns = cs_tree_node_get_tag(n, "oturns");
    const char *d      = cs_tree_node_get_tag(n, "description");
    const char *c_val  = cs_tree_node_get_tag(n, "value");
    const char *c_edit = cs_tree_node_get_tag(n, "editable");

    if (d == NULL)
      d = na;
    else if (strlen(d) == 0)
      d = na;

    int uncertain = -1;
    if (oturns != NULL) {
      if (strcmp(oturns, "Yes: Input") == 0)
        uncertain = 0;
      else if (strcmp(oturns, "Yes: Output") == 0)
        uncertain = 1;
    }
    bool editable = false;
    if (c_edit != NULL)
      if (strcmp(c_edit, "Yes") == 0)
        editable = true;

    /* If the variable is an uncertain output, it has to be modified
     * by the code, hence editable=true
     */
    if (uncertain == 1)
      editable = true;

    _cs_notebook_entry_t *e = _entry_create(name, uncertain, editable);

    _entry_set_description(e, d);
    cs_real_t val = atof(c_val);
    _entry_set_value(e, val);

  }
  cs_notebook_log();
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Check if a parameter value is present.
 *
 * \param[in]   name      name of the parameter
 * \param[out]  editable  1 if the value is editable, 0 otherwise (optional)
 *
 * \return 0 if not present, 1 if present
 */
/*----------------------------------------------------------------------------*/

int
cs_notebook_parameter_is_present(const char  *name,
                                 int         *editable)
{
  int retval = 0;
  int id = cs_map_name_to_id_try(_entry_map, name);

  if (editable != NULL)
    *editable = 0;

  if (id > -1) {
    retval = 1;
    if (editable != NULL) {
      if (_entries[id]->editable)
        *editable = 1;
    }
  }
  return retval;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Return a parameter value (real).
 *
 * The name used is the same as the one in the GUI
 *
 * \param[in] name  name of the parameter
 *
 * \return value of the given parameter
 */
/*----------------------------------------------------------------------------*/

cs_real_t
cs_notebook_parameter_value_by_name(const char *name)
{
  _cs_notebook_entry_t *e = cs_notebook_entry_by_name(name);
  return e->val;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Set a parameter value (real) for an editable parameter.
 *
 * The name used is the same as the one in the GUI
 *
 * \param[in] name  name of the parameter
 * \param[in] val   value of the parameter
 */
/*----------------------------------------------------------------------------*/

void
cs_notebook_parameter_set_value(const char *name,
                                cs_real_t   val)
{
  _cs_notebook_entry_t *e = cs_notebook_entry_by_name(name);

  if (e->editable == false)
    bft_error(__FILE__, __LINE__, 0,
              _("Entry \"%s\" was defined as not editable in the notebook.\n"),
              e->name);

  _entry_set_value(e, val);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Indicate whether the parameter is used for a study with openturns.
 *
 * Returns an int flag to indicate whether this paramter is used for an
 * OpenTurns study.
 *  -1 : The parameter is not used with OpenTurns
 *   0 : The parameter is used as an input from OpenTurns
 *   1 : The parameter is used as an output to OpenTurns
 *
 * \param[in] name  name of the parameter
 *
 * \return  an int flag value
 */
/*----------------------------------------------------------------------------*/

int
cs_notebook_parameter_get_openturns_status(char *name)
{
  _cs_notebook_entry_t *e = cs_notebook_entry_by_name(name);
  return e->uncertain;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Returns the description of the parameter (GUI defined)
 *
 * \param[in] name  name of the parameter
 *
 * \return  a const char pointer containing the description.
 *
 */
/*----------------------------------------------------------------------------*/

const char *
cs_notebook_parameter_get_description(char *name)
{
  _cs_notebook_entry_t *e = cs_notebook_entry_by_name(name);
  return e->description;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Writes uncertain values to output file
 *
 * If input and output uncertain variables are provided, output values
 * are written to an output file : cs_uncertain_output.dat
 * Results are ordered in the definition order in the notebook.
 *
 */
/*----------------------------------------------------------------------------*/

void
cs_notebook_uncertain_output(void)
{
  if (_n_uncertain_inputs == 0 || _n_uncertain_outputs == 0)
    return;

  if (cs_glob_rank_id <= 0) {
    FILE *file = fopen("cs_uncertain_output.dat", "w");

    /* Write header */
    fprintf(file, "#");
    for (int i = 0; i < _n_entries; i++) {
      if (_entries[i]->uncertain == 1)
        fprintf(file, " %s", _entries[i]->name);
    }
    fprintf(file, "\n");

    /* Write values */
    int count = 0;
    for (int i = 0; i < _n_entries; i++) {
      if (_entries[i]->uncertain == 1) {
        if (count == 0)
          count += 1;
        else
          fprintf(file, ", ");

        fprintf(file, "%f", _entries[i]->val);
      }
    }
    fflush(file);
    fclose(file);
  }
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Destroy the notebook structure
 *
 * Destroys the structures related to the notebook
 *
 */
/*----------------------------------------------------------------------------*/

void
cs_notebook_destroy_all(void)
{
  /* Before destruction, we dump the results */
  cs_notebook_uncertain_output();

  for (int i = 0; i < _n_entries; i++) {
    _cs_notebook_entry_t *e = _entries[i];
    BFT_FREE(e->description);
  }

  for (int i = 0; i < _n_entries; i++) {
    if (i % _CS_NOTEBOOK_ENTRY_S_ALLOC_SIZE == 0)
      BFT_FREE(_entries[i]);
  }

  BFT_FREE(_entries);

  cs_map_name_to_id_destroy(&_entry_map);

  _n_entries     = 0;
  _n_entries_max = 0;
}

/*----------------------------------------------------------------------------*/

END_C_DECLS
