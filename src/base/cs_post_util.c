/*============================================================================
 * Postprocessing utility functions.
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

/*----------------------------------------------------------------------------
 * Standard C library headers
 *----------------------------------------------------------------------------*/

#include <assert.h>
#include <math.h>
#include <string.h>

/*----------------------------------------------------------------------------
 * Local headers
 *----------------------------------------------------------------------------*/

#include "bft_mem.h"
#include "bft_printf.h"

#include "fvm_selector.h"

#include "cs_interface.h"

#include "cs_base.h"
#include "cs_balance_by_zone.h"
#include "cs_field.h"
#include "cs_field_pointer.h"
#include "cs_field_operator.h"
#include "cs_geom.h"
#include "cs_gradient.h"
#include "cs_gradient.h"
#include "cs_gradient_perio.h"
#include "cs_join.h"
#include "cs_halo.h"
#include "cs_halo_perio.h"
#include "cs_math.h"
#include "cs_matrix_default.h"
#include "cs_mesh.h"
#include "cs_mesh_coherency.h"
#include "cs_mesh_location.h"
#include "cs_mesh_quantities.h"
#include "cs_parall.h"
#include "cs_parameters.h"
#include "cs_physical_model.h"
#include "cs_physical_constants.h"
#include "cs_post.h"
#include "cs_prototypes.h"
#include "cs_renumber.h"
#include "cs_rotation.h"
#include "cs_stokes_model.h"
#include "cs_thermal_model.h"
#include "cs_time_step.h"
#include "cs_timer.h"
#include "cs_timer_stats.h"
#include "cs_turbomachinery.h"
#include "cs_turbulence_model.h"

/*----------------------------------------------------------------------------
 * Header for the current file
 *----------------------------------------------------------------------------*/

#include "cs_post_util.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*! \cond DOXYGEN_SHOULD_SKIP_THIS */

/*============================================================================
 * Local structure definitions
 *============================================================================*/

/*============================================================================
 * Static global variables
 *============================================================================*/

/*! Status of post utilities */

int cs_glob_post_util_flag[CS_POST_UTIL_N_TYPES]
  = {-1, -1};

/*============================================================================
 * Private function definitions
 *============================================================================*/

/*! (DOXYGEN_SHOULD_SKIP_THIS) \endcond */

/*============================================================================
 * Public function definitions
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief Select cells cut by a given segment
 *
 * This selection function may be used as an elements selection function
 * for postprocessing.
 *
 * In this case, the input points to a real array containing the segment's
 * start and end coordinates.
 *
 * Note: the input pointer must point to valid data when this selection
 * function is called, so either:
 * - that value or structure should not be temporary (i.e. local);
 * - post-processing output must be ensured using cs_post_write_meshes()
 *   with a fixed-mesh writer before the data pointed to goes out of scope;
 *
 * The caller is responsible for freeing the returned cell_ids array.
 * When passed to postprocessing mesh or probe set definition functions,
 * this is handled automatically.
 *
 * \param[in]   input     pointer to segment start and end:
 *                        [x0, y0, z0, x1, y1, z1]
 * \param[out]  n_cells   number of selected cells
 * \param[out]  cell_ids  array of selected cell ids (0 to n-1 numbering)
 */
/*----------------------------------------------------------------------------*/

void
cs_cell_segment_intersect_select(void        *input,
                                 cs_lnum_t   *n_cells,
                                 cs_lnum_t  **cell_ids)
{
  cs_real_t *sx = (cs_real_t *)input;

  const cs_real_t sx0[3] = {sx[0], sx[1], sx[2]};
  const cs_real_t sx1[3] = {sx[3], sx[4], sx[5]};

  const cs_mesh_t *m = cs_glob_mesh;
  const cs_mesh_quantities_t  *fvq = cs_glob_mesh_quantities;

  cs_lnum_t _n_cells = m->n_cells;
  cs_lnum_t *_cell_ids = NULL;

  const int n_i_groups = m->i_face_numbering->n_groups;
  const int n_i_threads = m->i_face_numbering->n_threads;
  const int n_b_groups = m->b_face_numbering->n_groups;
  const int n_b_threads = m->b_face_numbering->n_threads;
  const cs_lnum_t *restrict i_group_index = m->i_face_numbering->group_index;
  const cs_lnum_t *restrict b_group_index = m->b_face_numbering->group_index;

  BFT_MALLOC(_cell_ids, _n_cells, cs_lnum_t); /* Allocate selection list */

  /* Mark for each cell */
  /*--------------------*/

  for (cs_lnum_t cell_id = 0; cell_id < _n_cells; cell_id++) {
    _cell_ids[cell_id] = -1;
  }

  const cs_real_3_t *vtx_coord= (const cs_real_3_t *)m->vtx_coord;

  /* Contribution from interior faces;
     note the to mark cells, we could use a simple loop,
     as thread races would not lead to a incorrect result, but
     even if is slightly slower, we prefer to have a clean
     behavior under thread debuggers. */

  for (int g_id = 0; g_id < n_i_groups; g_id++) {

#   pragma omp parallel for
    for (int t_id = 0; t_id < n_i_threads; t_id++) {

      for (cs_lnum_t face_id = i_group_index[(t_id*n_i_groups + g_id)*2];
           face_id < i_group_index[(t_id*n_i_groups + g_id)*2 + 1];
           face_id++) {

        int n_inout[2] = {0, 0};

        cs_lnum_t vtx_start = m->i_face_vtx_idx[face_id];
        cs_lnum_t vtx_end = m->i_face_vtx_idx[face_id+1];
        cs_lnum_t n_vertices = vtx_end - vtx_start;
        const cs_lnum_t *vertex_ids = m->i_face_vtx_lst + vtx_start;

        const cs_real_t *face_center = fvq->i_face_cog + (3*face_id);

        double t = cs_geom_segment_intersect_face(0,
                                                  n_vertices,
                                                  vertex_ids,
                                                  vtx_coord,
                                                  face_center,
                                                  sx0,
                                                  sx1,
                                                  n_inout,
                                                  NULL);

        if (t >= 0 && t <= 1) {
          cs_lnum_t  c_id0 = m->i_face_cells[face_id][0];
          cs_lnum_t  c_id1 = m->i_face_cells[face_id][1];
          if (c_id0 < _n_cells)
            _cell_ids[c_id0] = 1;
          if (c_id1 < _n_cells)
            _cell_ids[c_id1] = 1;
        }

      }

    }

  }

  /* Contribution from boundary faces*/

  for (int g_id = 0; g_id < n_b_groups; g_id++) {

#   pragma omp parallel for
    for (int t_id = 0; t_id < n_b_threads; t_id++) {

      for (cs_lnum_t face_id = b_group_index[(t_id*n_b_groups + g_id)*2];
           face_id < b_group_index[(t_id*n_b_groups + g_id)*2 + 1];
           face_id++) {

        int n_inout[2] = {0, 0};

        cs_lnum_t vtx_start = m->b_face_vtx_idx[face_id];
        cs_lnum_t vtx_end = m->b_face_vtx_idx[face_id+1];
        cs_lnum_t n_vertices = vtx_end - vtx_start;
        const cs_lnum_t *vertex_ids = m->b_face_vtx_lst + vtx_start;

        const cs_real_t *face_center = fvq->b_face_cog + (3*face_id);

        double t = cs_geom_segment_intersect_face(0,
                                                  n_vertices,
                                                  vertex_ids,
                                                  vtx_coord,
                                                  face_center,
                                                  sx0,
                                                  sx1,
                                                  n_inout,
                                                  NULL);

        if (t >= 0 && t <= 1) {
          cs_lnum_t  c_id = m->b_face_cells[face_id];
          _cell_ids[c_id] = 1;
        }

      }

    }

  }

  /* Now check marked cells */

  _n_cells = 0;
  for (cs_lnum_t cell_id = 0; cell_id < m->n_cells; cell_id++) {
    if (_cell_ids[cell_id] >= 0)
      _cell_ids[_n_cells++] = cell_id;
  }

  BFT_REALLOC(_cell_ids, _n_cells, cs_lnum_t); /* Adjust size (good practice,
                                                  but not required) */

  /* Set return values */

  *n_cells = _n_cells;
  *cell_ids = _cell_ids;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Select cells cut by a line composed of segments
 *
 * This selection function may be used as an elements selection function
 * for postprocessing.
 *
 * In this case, the input points to a real array containing the segment's
 * start and end coordinates.
 *
 * Note: the input pointer must point to valid data when this selection
 * function is called, so either:
 * - that value or structure should not be temporary (i.e. local);
 * - post-processing output must be ensured using cs_post_write_meshes()
 *   with a fixed-mesh writer before the data pointed to goes out of scope;
 *
 * The caller is responsible for freeing the returned cell_ids array.
 * When passed to postprocessing mesh or probe set definition functions,
 * this is handled automatically.
 *
 * \param[in]   input     pointer to segments starts and ends:
 *                        [x0, y0, z0, x1, y1, z1]
 * \param[in]   n_points  number of vertices in the polyline
 * \param[out]  n_cells   number of selected cells
 * \param[out]  cell_ids  array of selected cell ids (0 to n-1 numbering)
 * \param[out]  seg_c_len array of length of the segment in the selected cells
 */
/*----------------------------------------------------------------------------*/

void
cs_cell_polyline_intersect_select(void        *input,
                                  cs_lnum_t   n_points,
                                  cs_lnum_t   *n_cells,
                                  cs_lnum_t  **cell_ids,
                                  cs_real_t  **seg_c_len)
{
  cs_real_t *sx = (cs_real_t *)input;

  const cs_mesh_t *m = cs_glob_mesh;
  const cs_mesh_quantities_t  *fvq = cs_glob_mesh_quantities;

  cs_lnum_t _n_cells = m->n_cells;
  cs_lnum_t *_cell_ids = NULL;
  cs_lnum_t *_in = NULL;
  cs_lnum_t *_out = NULL;
  cs_real_t *_seg_c_len = NULL;

  const int n_i_groups = m->i_face_numbering->n_groups;
  const int n_i_threads = m->i_face_numbering->n_threads;
  const int n_b_groups = m->b_face_numbering->n_groups;
  const int n_b_threads = m->b_face_numbering->n_threads;
  const cs_lnum_t *restrict i_group_index = m->i_face_numbering->group_index;
  const cs_lnum_t *restrict b_group_index = m->b_face_numbering->group_index;

  BFT_MALLOC(_cell_ids, _n_cells, cs_lnum_t); /* Allocate selection list */
  BFT_MALLOC(_seg_c_len, _n_cells, cs_real_t); /* Allocate selection list length */
  BFT_MALLOC(_in, _n_cells, cs_lnum_t);
  BFT_MALLOC(_out, _n_cells, cs_lnum_t);

  /* Mark for each cell */
  /*--------------------*/

  for (cs_lnum_t cell_id = 0; cell_id < _n_cells; cell_id++) {
    _cell_ids[cell_id] = -1;
    _seg_c_len[cell_id] = 0.;
  }

  const cs_real_3_t *vtx_coord= (const cs_real_3_t *)m->vtx_coord;

  /* Loop over the vertices of the polyline */
  for (cs_lnum_t s_id = 0; s_id < n_points - 1; s_id++) {

    const cs_real_t *sx0 = &(sx[3*s_id]);
    const cs_real_t *sx1 = &(sx[3*(s_id+1)]);

    cs_real_t length =  cs_math_3_distance(sx0, sx1);

    /* Count the number of ingoing and outgoing intersection
     * to check if the segment is inside the cell */
    for (cs_lnum_t cell_id = 0; cell_id < _n_cells; cell_id++) {
      _in[cell_id] = 0;
      _out[cell_id] = 0;
    }

    /* Contribution from interior faces;
       note the to mark cells, we could use a simple loop,
       as thread races would not lead to a incorrect result, but
       even if is slightly slower, we prefer to have a clean
       behavior under thread debuggers. */

    for (int g_id = 0; g_id < n_i_groups; g_id++) {

#   pragma omp parallel for
      for (int t_id = 0; t_id < n_i_threads; t_id++) {

        for (cs_lnum_t face_id = i_group_index[(t_id*n_i_groups + g_id)*2];
            face_id < i_group_index[(t_id*n_i_groups + g_id)*2 + 1];
            face_id++) {

          cs_lnum_t vtx_start = m->i_face_vtx_idx[face_id];
          cs_lnum_t vtx_end = m->i_face_vtx_idx[face_id+1];
          cs_lnum_t n_vertices = vtx_end - vtx_start;
          const cs_lnum_t *vertex_ids = m->i_face_vtx_lst + vtx_start;

          const cs_real_t *face_center = fvq->i_face_cog + (3*face_id);

          cs_lnum_t c_id0 = m->i_face_cells[face_id][0];
          cs_lnum_t c_id1 = m->i_face_cells[face_id][1];

          /* The line (OD) goes in (n_inout[0]++)
           * or goes out (n_inout[1]++) the cell */
          int n_inout[2] = {0, 0};

          double t = cs_geom_segment_intersect_face(0,
                                                    n_vertices,
                                                    vertex_ids,
                                                    vtx_coord,
                                                    face_center,
                                                    sx0,
                                                    sx1,
                                                    n_inout,
                                                    NULL);

          /* Segment is inside if n_inout[0] > 0
           * and n_inout[1] > 0 for two faces */
          if (c_id0 < _n_cells) {
            /* Intersection of (OD) with the face
             * may be on [OD)
             * It may leave c_id0 */
            if (t >= 0.)
              _out[c_id0] += n_inout[1];

            /* Intersection of (OD) with the face
             * may be on (OD]
             * It may enter c_id0 */
            if (t < 0)
              _in[c_id0] += n_inout[0];
          }
          if (c_id1 < _n_cells) {
            /* Intersection of (OD) with the face
             * may be on [OD)
             * It may enter c_id1 */
            if (t >= 0.)
              _out[c_id1] += n_inout[0];

            /* Intersection of (OD) with the face
             * may be on (OD]
             * It may leave c_id0 */
            if (t < 0.)
              _in[c_id1] += n_inout[1];
          }

          /* Segment crosses the face */
          if (t >= 0 && t <= 1) {
            /* length upwind the face*/
            cs_real_t length_up =  t * length;
            /* length downwind the face*/
            cs_real_t length_down =  (1.-t) * length;
            if (c_id0 < _n_cells) {

              /* Mark cell by segment id (the cell may already be marked by another
               * segment */
              _cell_ids[c_id0] = s_id;

              /* OD enters cell i from cell j */
              if (n_inout[0] > 0)
                _seg_c_len[c_id0] -= length_up;

              /* OD leaves cell i to cell j */
              if (n_inout[1] > 0)
                _seg_c_len[c_id0] -= length_down;

            }
            if (c_id1 < _n_cells) {

              /* Mark cell by segment id (the cell may already be marked by another
               * segment */
              _cell_ids[c_id1] = s_id;

              /* OD enters cell i from cell j
               * so leaves cell j */
              if (n_inout[0] > 0)
                _seg_c_len[c_id1] -= length_down;

              /* OD leaves cell i to cell j
               * so enters cell j */
              if (n_inout[1] > 0)
                _seg_c_len[c_id1] -= length_up;

            }
          }
        }

      }

    }


    /* Contribution from boundary faces*/

    for (int g_id = 0; g_id < n_b_groups; g_id++) {

#   pragma omp parallel for
      for (int t_id = 0; t_id < n_b_threads; t_id++) {

        for (cs_lnum_t face_id = b_group_index[(t_id*n_b_groups + g_id)*2];
            face_id < b_group_index[(t_id*n_b_groups + g_id)*2 + 1];
            face_id++) {

          cs_lnum_t vtx_start = m->b_face_vtx_idx[face_id];
          cs_lnum_t vtx_end = m->b_face_vtx_idx[face_id+1];
          cs_lnum_t n_vertices = vtx_end - vtx_start;
          const cs_lnum_t *vertex_ids = m->b_face_vtx_lst + vtx_start;

          const cs_real_t *face_center = fvq->b_face_cog + (3*face_id);
          cs_lnum_t  c_id = m->b_face_cells[face_id];

          int n_inout[2] = {0, 0};

          double t = cs_geom_segment_intersect_face(0,
                                                    n_vertices,
                                                    vertex_ids,
                                                    vtx_coord,
                                                    face_center,
                                                    sx0,
                                                    sx1,
                                                    n_inout,
                                                    NULL);

          /* Segment is inside if n_inout[0] > 0
           * and n_inout[1] > 0 for two faces */
          if (c_id < _n_cells) {
            /* Intersection of (OD) with the face
             * may be on [OD)
             * It may leave c_id */
            if (t >= 0.)
              _out[c_id] += n_inout[1];

            /* Intersection of (OD) with the face
             * may be on (OD]
             * It may enter c_id */
            if (t < 0)
              _in[c_id] += n_inout[0];
          }

          /* Segment crosses the face */
          if (t >= 0 && t <= 1) {

            /* length upwind the face*/
            cs_real_t length_up =  t * length;
            /* length downwind the face*/
            cs_real_t length_down =  (1.-t) * length;

            /* Mark cell by segment id (the cell may already be marked by another
             * segment */
            _cell_ids[c_id] = s_id;

            /* OD enters cell i */
            if (n_inout[0] > 0)
              _seg_c_len[c_id] -= length_up;

            /* OD leaves cell i */
            if (n_inout[1] > 0)
              _seg_c_len[c_id] -= length_down;

          }

        }
      }

    }

    /* Finalize the lenght computation to deal with cases where the segment
     * is inside the cell */
    for (cs_lnum_t cell_id = 0; cell_id < m->n_cells; cell_id++) {
      /* There is one intersection on the left of [OD)
       * and one on the right of [OD) which means that
       * O is inside the cell */
      if ((_in[cell_id] > 0 && _out[cell_id] > 0)
          || (_cell_ids[cell_id] == s_id)) {
        _cell_ids[cell_id] = s_id;
        _seg_c_len[cell_id] += length;
      }
    }

  } /* End loop over the segments */

  BFT_FREE(_in);
  BFT_FREE(_out);

  /* Now check marked cells and renumber */
  _n_cells = 0;
  for (cs_lnum_t cell_id = 0; cell_id < m->n_cells; cell_id++) {
    if (_cell_ids[cell_id] >= 0) {
      _cell_ids[_n_cells] = cell_id;
      _seg_c_len[_n_cells] = _seg_c_len[cell_id];
      _n_cells++;
    }
  }

  BFT_REALLOC(_cell_ids, _n_cells, cs_lnum_t); /* Adjust size (good practice,
                                                  but not required) */
  BFT_REALLOC(_seg_c_len, _n_cells, cs_real_t);

  /* Set return values */

  *n_cells = _n_cells;
  *cell_ids = _cell_ids;
  *seg_c_len = _seg_c_len;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Define probes based on the centers of cells intersected by
 *        a given segment.
 *
 * This selection function may be used as a probe set definition function
 * for postprocessing.
 *
 * In this case, the input points to a real array containing the segment's
 * start and end coordinates.
 *
 * Note: the input pointer must point to valid data when this selection
 * function is called, so either:
 * - that value or structure should not be temporary (i.e. local);
 * - post-processing output must be ensured using cs_post_write_meshes()
 *   with a fixed-mesh writer before the data pointed to goes out of scope;
 *
 * The caller is responsible for freeing the returned cell_ids array.
 * When passed to postprocessing mesh or probe set definition functions,
 * this is handled automatically.
 *
 * \param[in]   input   pointer to segment start and end:
 *                      [x0, y0, z0, x1, y1, z1]
 * \param[out]  n_elts  number of selected coordinates
 * \param[out]  coords  coordinates of selected elements.
 * \param[out]  s       curvilinear coordinates of selected elements
 */
/*----------------------------------------------------------------------------*/

void
cs_cell_segment_intersect_probes_define(void          *input,
                                        cs_lnum_t     *n_elts,
                                        cs_real_3_t  **coords,
                                        cs_real_t    **s)
{
  cs_real_t *sx = (cs_real_t *)input;

  const cs_real_t dx1[3] = {sx[3]-sx[0], sx[4]-sx[1], sx[5]-sx[2]};
  const cs_real_t s_norm2 = cs_math_3_square_norm(dx1);

  const cs_real_3_t  *cell_cen
    = (const cs_real_3_t *)(cs_glob_mesh_quantities->cell_cen);

  cs_lnum_t n_cells = 0;
  cs_lnum_t *cell_ids = NULL;

  cs_cell_segment_intersect_select(input, &n_cells, &cell_ids);

  cs_real_3_t *_coords;
  cs_real_t *_s;
  BFT_MALLOC(_coords, n_cells, cs_real_3_t);
  BFT_MALLOC(_s, n_cells, cs_real_t);

  for (cs_lnum_t i = 0; i < n_cells; i++) {
    cs_real_t dx[3], coo[3];
    for (cs_lnum_t j = 0; j < 3; j++) {
      coo[j] = cell_cen[cell_ids[i]][j];
      dx[j] = coo[j] - sx[j];
      _coords[i][j] = coo[j];
    }
    _s[i] = cs_math_3_dot_product(dx, dx1) / s_norm2;
  }

  BFT_FREE(cell_ids);

  /* Set return values */

  *n_elts = n_cells;
  *coords = _coords;
  *s = _s;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Define a profile based on centers of faces defined by a given
 *        criterion
 *
 * Here, the input points to string describing a selection criterion.
 *
 * \param[in]   input   pointer to selection criterion
 * \param[out]  n_elts  number of selected coordinates
 * \param[out]  coords  coordinates of selected elements.
 * \param[out]  s       curvilinear coordinates of selected elements
 *----------------------------------------------------------------------------*/

void
cs_b_face_criterion_probes_define(void          *input,
                                  cs_lnum_t     *n_elts,
                                  cs_real_3_t  **coords,
                                  cs_real_t    **s)
{
  const char *criterion = (const char *)input;

  const cs_mesh_t *m = cs_glob_mesh;
  const cs_mesh_quantities_t *mq = cs_glob_mesh_quantities;

  cs_lnum_t   n_faces;
  cs_lnum_t  *face_ids;

  BFT_MALLOC(face_ids, m->n_b_faces, cs_lnum_t);
  cs_selector_get_b_face_list(criterion, &n_faces, face_ids);

  cs_real_3_t *_coords;
  cs_real_t *_s;
  BFT_MALLOC(_coords, n_faces, cs_real_3_t);
  BFT_MALLOC(_s, n_faces, cs_real_t);

  for (cs_lnum_t i = 0; i < n_faces; i++) {
    for (cs_lnum_t j = 0; j < 3; j++)
      _coords[i][j] = mq->b_face_cog[face_ids[i]*3 + j];
    _s[i] = _coords[i][0];
  }

  BFT_FREE(face_ids);

  /* Set return values */

  *n_elts = n_faces;
  *coords = _coords;
  *s = _s;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute the head of a turbomachinery (total pressure increase)
 *
 * \param[in]   criteria_in   selection criteria of turbomachinery suction
 * \param[in]   location_in   mesh location of turbomachinery suction
 * \param[in]   criteria_out  selection criteria of turbomachinery discharge
 * \param[in]   location_out  mesh location of turbomachinery discharge
 *
 * \return turbomachinery head
 */
/*----------------------------------------------------------------------------*/

cs_real_t
cs_post_turbomachinery_head(const char               *criteria_in,
                            cs_mesh_location_type_t   location_in,
                            const char               *criteria_out,
                            cs_mesh_location_type_t   location_out)
{
  cs_mesh_t *mesh = cs_glob_mesh;
  cs_mesh_quantities_t *mesh_quantities = cs_glob_mesh_quantities;

  cs_real_t *total_pressure = cs_field_by_name("total_pressure")->val;
  cs_real_3_t *vel = (cs_real_3_t *)CS_F_(vel)->val;
  cs_real_t *density = CS_F_(rho)->val;

  cs_real_t pabs_in = 0.;
  cs_real_t sum_in = 0.;
  cs_real_t pabs_out = 0.;
  cs_real_t sum_out = 0.;

  for (int _n = 0; _n < 2; _n++) {

    cs_lnum_t n_elts = 0;
    cs_lnum_t *elt_list = NULL;
    cs_real_t pabs = 0.;
    cs_real_t sum = 0.;

    cs_mesh_location_type_t location;
    const char *criteria = NULL;

    if (_n == 0) {
      location = location_in;
      criteria = criteria_in;
    } else {
      location = location_out;
      criteria = criteria_out;
    }

    switch(location) {
    case CS_MESH_LOCATION_CELLS:

      BFT_MALLOC(elt_list, mesh->n_cells, cs_lnum_t);
      cs_selector_get_cell_list(criteria, &n_elts, elt_list);

      for (cs_lnum_t i = 0; i < n_elts; i++) {
        cs_lnum_t cell_id = elt_list[i];
        cs_real_t weight = mesh_quantities->cell_vol[cell_id];
        pabs += weight*(total_pressure[cell_id] + 0.5*density[cell_id]*
                        cs_math_3_square_norm(vel[cell_id]));
        sum += weight;
      }
      BFT_FREE(elt_list);
      break;

    case CS_MESH_LOCATION_BOUNDARY_FACES:

      BFT_MALLOC(elt_list, mesh->n_b_faces, cs_lnum_t);
      cs_selector_get_b_face_list(criteria, &n_elts, elt_list);

      for (cs_lnum_t i = 0; i < n_elts; i++) {
        cs_lnum_t face_id = elt_list[i];
        cs_lnum_t cell_id = mesh->b_face_cells[face_id];
        cs_real_t surf = mesh_quantities->b_face_surf[face_id];
        pabs += surf*(total_pressure[cell_id] + 0.5*density[cell_id]
                      *cs_math_3_square_norm(vel[cell_id]));
        sum += surf;
      }
      BFT_FREE(elt_list);
      break;

    case CS_MESH_LOCATION_INTERIOR_FACES:

      BFT_MALLOC(elt_list, mesh->n_i_faces, cs_lnum_t);
      cs_selector_get_i_face_list(criteria, &n_elts, elt_list);

      for (cs_lnum_t i = 0; i < n_elts; i++) {
        cs_lnum_t face_id = elt_list[i];
        cs_lnum_t c_i = mesh->i_face_cells[face_id][0];
        cs_lnum_t c_j = mesh->i_face_cells[face_id][1];
        cs_real_t w = mesh_quantities->i_face_surf[face_id];

        cs_real_t pt = w*total_pressure[c_i] + (1.-w)*total_pressure[c_j];
        cs_real_t r = w*density[c_i] + (1.-w)*density[c_j];
        cs_real_3_t v = {w*vel[c_i][0] + (1.-w)*vel[c_j][0],
                         w*vel[c_i][1] + (1.-w)*vel[c_j][1],
                         w*vel[c_i][2] + (1.-w)*vel[c_j][2]};
        pabs += w*(pt + 0.5*r*cs_math_3_square_norm(v));
        sum += w;
      }
      BFT_FREE(elt_list);
      break;

    default:
      pabs = 0.;
      sum = 1.;
      bft_printf
        (_("Warning: while post-processing the turbomachinery head.\n"
           "         Mesh location %d is not supported, so the computed head\n"
           "         is erroneous.\n"
           "         The %s parameters should be checked.\n"),
           location, __func__);
      break;
    }

    if (_n == 0) {
      pabs_in = pabs;
      sum_in = sum;
    } else {
      pabs_out = pabs;
      sum_out = sum;
    }

  }

  double _s[4] = {pabs_in, pabs_out, sum_in, sum_out};
  cs_parall_sum(4, CS_DOUBLE, _s);

  pabs_in  = _s[0] / _s[2];
  pabs_out = _s[1] / _s[3];

  return pabs_out - pabs_in;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Compute the magnitude of a moment of force torque) given an
 *         axis and the stress on a specific boundary.
 *
 * \param[in]   n_b_faces    number of faces
 * \param[in]   b_face_ids   list of faces (0 to n-1)
 * \param[in]   axis         axis
 *
 * \return couple about the axis
 */
/*----------------------------------------------------------------------------*/

cs_real_t
cs_post_moment_of_force(cs_lnum_t        n_b_faces,
                        const cs_lnum_t  b_face_ids[],
                        cs_real_t        axis[3])
{
  const cs_real_3_t *b_face_cog
    = (const cs_real_3_t *)cs_glob_mesh_quantities->b_face_cog;
  const cs_real_3_t *b_forces
    = (const cs_real_3_t *)cs_field_by_name("boundary_forces")->val;

  cs_real_3_t moment = {0., 0., 0.};

  for (cs_lnum_t i = 0; i < n_b_faces; i++) {
    cs_real_3_t m;
    cs_lnum_t face_id = b_face_ids[i];
    cs_math_3_cross_product(b_face_cog[face_id], b_forces[face_id], m);

    /* b_forces is the stress on the solid boundary,
       thus it comes with a '-' sign here */
    for (int j = 0; j < 3; j++)
      moment[j] -= m[j];
  }
  cs_parall_sum(3, CS_DOUBLE, moment);

  return cs_math_3_dot_product(moment, axis);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute tangential stress on a specific boundary.
 *
 * \param[in]   n_b_faces    number of faces
 * \param[in]   b_face_ids   list of faces (0 to n-1)
 * \param[out]  stress       tangential stress on the specific
 *                           boundary
 */
/*----------------------------------------------------------------------------*/

void
cs_post_stress_tangential(cs_lnum_t        n_b_faces,
                          const cs_lnum_t  b_face_ids[],
                          cs_real_3_t      stress[])
{
  const cs_real_3_t *surfbo =
    (const cs_real_3_t *)cs_glob_mesh_quantities->b_face_normal;
  const cs_real_t *surfbn = cs_glob_mesh_quantities->b_face_surf;
  const cs_real_3_t *forbr =
    (const cs_real_3_t *)cs_field_by_name("boundary_forces")->val;
  cs_lnum_t ifac;
  cs_real_t srfbn, srfnor[3], fornor;

  for (cs_lnum_t iloc = 0 ; iloc < n_b_faces; iloc++) {
    ifac = b_face_ids[iloc];
    srfbn = surfbn[ifac];
    srfnor[0] = surfbo[ifac][0] / srfbn;
    srfnor[1] = surfbo[ifac][1] / srfbn;
    srfnor[2] = surfbo[ifac][2] / srfbn;
    fornor = forbr[ifac][0]*srfnor[0]
           + forbr[ifac][1]*srfnor[1]
           + forbr[ifac][2]*srfnor[2];
    stress[iloc][0] = (forbr[ifac][0] - fornor*srfnor[0]) / srfbn;
    stress[iloc][1] = (forbr[ifac][1] - fornor*srfnor[1]) / srfbn;
    stress[iloc][2] = (forbr[ifac][2] - fornor*srfnor[2]) / srfbn;
  }
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute pressure on a specific boundary region.
 *
 * \param[in]   n_b_faces    number of faces
 * \param[in]   b_face_ids   list of faces (0 to n-1)
 * \param[in]   hyd_p_flag   flag for hydrostatic pressure
 * \param[in]   f_ext        exterior force generating
 *                           the hydrostatic pressure
 * \param[out]  pres         pressure on a specific boundary region
 */
/*----------------------------------------------------------------------------*/

void
cs_post_b_pressure(cs_lnum_t         n_b_faces,
                   const cs_lnum_t   b_face_ids[],
                   cs_real_t         pres[])
{
  const cs_mesh_t *m = cs_glob_mesh;
  const cs_mesh_quantities_t *mq = cs_glob_mesh_quantities;
  const cs_real_3_t *diipb = (const cs_real_3_t *)mq->diipb;
  cs_real_3_t *gradp;

  BFT_MALLOC(gradp, m->n_cells_with_ghosts, cs_real_3_t);

  int hyd_p_flag = cs_glob_stokes_model->iphydr;
  cs_real_3_t *f_ext = (hyd_p_flag == 1) ?
    (cs_real_3_t *)cs_field_by_name_try("volume_forces"):NULL;

  bool use_previous_t = false;
  int inc = 1;
  int recompute_cocg = 1;
  cs_field_gradient_potential(CS_F_(p),
                              use_previous_t,
                              inc,
                              recompute_cocg,
                              hyd_p_flag,
                              f_ext,
                              gradp);

  for (cs_lnum_t iloc = 0 ; iloc < n_b_faces; iloc++) {
    cs_lnum_t face_id = b_face_ids[iloc];
    cs_lnum_t cell_id = m->b_face_cells[face_id];

    cs_real_t pip =   CS_F_(p)->val[cell_id]
                    + cs_math_3_dot_product(gradp[cell_id],
                                            diipb[face_id]);
    pres[iloc] =   CS_F_(p)->bc_coeffs->a[face_id]
                 + CS_F_(p)->bc_coeffs->b[face_id]*pip;


  }
  BFT_FREE(gradp);

  const cs_turb_model_t  *turb_model = cs_get_glob_turb_model();

  if (   turb_model->itytur == 2
      && turb_model->itytur == 6
      && turb_model->itytur == 5) {
    cs_real_3_t *gradk;
    BFT_MALLOC(gradk, m->n_cells_with_ghosts, cs_real_3_t);

    use_previous_t = false;
    inc = 1;
    recompute_cocg = 1;
    cs_field_gradient_scalar(CS_F_(k),
                             use_previous_t,
                             inc,
                             recompute_cocg,
                             gradk);

    for (cs_lnum_t iloc = 0 ; iloc < n_b_faces; iloc++) {
      cs_lnum_t face_id = b_face_ids[iloc];
      cs_lnum_t cell_id = m->b_face_cells[face_id];

      cs_real_t kip =   CS_F_(k)->val[cell_id]
        + cs_math_3_dot_product(gradk[cell_id],
                                diipb[face_id]);
      pres[iloc] -= 2./3.*CS_F_(rho_b)->val[face_id]
                         *(  CS_F_(k)->bc_coeffs->a[face_id]
                           + CS_F_(k)->bc_coeffs->b[face_id]*kip);
    }
    BFT_FREE(gradk);
  }
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute Reynolds stresses in case of Eddy Viscosity Models
 *
 * \param[in]  interpolation_type interpolation type for turbulent kinetic
 *                                energy field
 * \param[in]  n_cells            number of points
 * \param[in]  cell_ids           cell location of points
 *                                (indexed from 0 to n-1)
 * \param[in]  coords             point coordinates
 * \param[out] rst                Reynolds stresses stored as vector
 *                                [r11,r22,r33,r12,r23,r13]
 */
/*----------------------------------------------------------------------------*/

void
cs_post_evm_reynolds_stresses(cs_field_interpolate_t  interpolation_type,
                              cs_lnum_t               n_cells,
                              const cs_lnum_t         cell_ids[],
                              const cs_real_3_t      *coords,
                              cs_real_6_t            *rst)
{
  const cs_turb_model_t  *turb_model = cs_get_glob_turb_model();
  const cs_lnum_t n_cells_ext = cs_glob_mesh->n_cells_with_ghosts;

  if (   turb_model->itytur != 2
      && turb_model->itytur != 6
      && turb_model->itytur != 5)
    bft_error(__FILE__, __LINE__, 0,
              _("This post-processing utility function is only available for "
                "Eddy Viscosity Models."));

  /* velocity gradient */

  cs_real_33_t *gradv;
  BFT_MALLOC(gradv, n_cells_ext, cs_real_33_t);

  bool use_previous_t = false;
  int inc = 1;
  cs_field_gradient_vector(CS_F_(vel),
                           use_previous_t,
                           inc,
                           gradv);

  cs_real_t *xk;
  BFT_MALLOC(xk, n_cells, cs_real_t);

  cs_field_interpolate(CS_F_(k),
                       interpolation_type,
                       n_cells,
                       cell_ids,
                       coords,
                       xk);

  /* Compute Reynolds stresses */

  const cs_real_t d2s3 = 2./3.;
  for (cs_lnum_t iloc = 0; iloc < n_cells; iloc++) {
    cs_lnum_t iel = cell_ids[iloc];

    cs_real_t divu = gradv[iel][0][0] + gradv[iel][1][1] + gradv[iel][2][2];
    cs_real_t nut = CS_F_(mu_t)->val[iel]/CS_F_(rho)->val[iel];

    cs_real_t xdiag = d2s3*(xk[iloc]+ nut*divu);
    rst[iloc][0] =  xdiag - 2.*nut*gradv[iel][0][0];
    rst[iloc][1] =  xdiag - 2.*nut*gradv[iel][1][1];
    rst[iloc][2] =  xdiag - 2.*nut*gradv[iel][2][2];
    rst[iloc][3] = -nut*(gradv[iel][1][0]+gradv[iel][0][1]);
    rst[iloc][4] = -nut*(gradv[iel][2][1]+gradv[iel][1][2]);
    rst[iloc][5] = -nut*(gradv[iel][2][0]+gradv[iel][0][2]);
  }

  BFT_FREE(gradv);
  BFT_FREE(xk);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute the invariant of the anisotropy tensor
 *
 * \param[in]  n_cells            number of points
 * \param[in]  cell_ids           cell location of points
 *                                (indexed from 0 to n-1)
 * \param[in]  coords             point coordinates
 * \param[out] inv                Anisotropy tensor invariant
 *                                [xsi, eta]
 */
/*----------------------------------------------------------------------------*/

void
cs_post_anisotropy_invariant(cs_lnum_t               n_cells,
                             const cs_lnum_t         cell_ids[],
                             const cs_real_3_t      *coords,
                             cs_real_2_t            *inv)
{
  const cs_turb_model_t  *turb_model = cs_get_glob_turb_model();
  const cs_turb_rans_model_t *turb_rans_mdl = cs_glob_turb_rans_model;
  const cs_lnum_t n_cells_ext = cs_glob_mesh->n_cells_with_ghosts;

  if (   turb_model->itytur != 2
      && turb_model->itytur != 3
      && turb_model->itytur != 6
      && turb_model->itytur != 5)
    bft_error(__FILE__, __LINE__, 0,
              _("This post-processing utility function is only available for "
                "RANS Models."));

  cs_real_6_t *rij = NULL;
  BFT_MALLOC(rij, n_cells, cs_real_6_t);
  cs_field_interpolate_t interpolation_type = CS_FIELD_INTERPOLATE_MEAN;

  /* Compute the Reynolds Stresses if we are using EVM */
  if (   turb_model->itytur != 2
      && turb_model->itytur != 6
      && turb_model->itytur != 5) {
    cs_post_evm_reynolds_stresses(interpolation_type,
                                  n_cells,
                                  cell_ids,
                                  coords, /* coords */
                                  rij);
  } else {
    if (turb_rans_mdl->irijco == 0) {
      for (cs_lnum_t i = 0; i < n_cells; i++) {
        cs_lnum_t c_id = cell_ids[i];
        rij[i][0] = CS_F_(r11)->val[c_id];
        rij[i][1] = CS_F_(r22)->val[c_id];
        rij[i][2] = CS_F_(r33)->val[c_id];
        rij[i][3] = CS_F_(r12)->val[c_id];
        rij[i][4] = CS_F_(r23)->val[c_id];
        rij[i][5] = CS_F_(r13)->val[c_id];
      }
    } else {
       cs_real_6_t *cvar_rij = (cs_real_6_t *)CS_F_(rij)->val;
       for (cs_lnum_t i = 0; i < n_cells; i++) {
         cs_lnum_t c_id = cell_ids[i];
         for (cs_lnum_t j = 0; j < 6; j++)
           rij[i][j] = cvar_rij[c_id][j];
        }

    }
  }

  /* Compute Invariants */

  const cs_real_t d1s3 = 1./3.;
  for (cs_lnum_t iloc = 0; iloc < n_cells; iloc++) {
    cs_lnum_t iel = cell_ids[iloc];

    cs_real_t xk = 0.5*(rij[iel][0]+rij[iel][1]+rij[iel][2]);
    cs_real_t bij[3][3];
    cs_real_t xeta, xksi ;

    bij[0][0] = rij[iel][0]/(2.0*xk) - d1s3;
    bij[1][1] = rij[iel][1]/(2.0*xk) - d1s3;
    bij[2][2] = rij[iel][2]/(2.0*xk) - d1s3;
    bij[0][1] = rij[iel][3]/(2.0*xk) ;
    bij[1][2] = rij[iel][4]/(2.0*xk) ;
    bij[0][2] = rij[iel][5]/(2.0*xk) ;
    bij[1][0] = bij[0][1] ;
    bij[2][1] = bij[1][2] ;
    bij[2][0] = bij[0][2] ;

    xeta = 0. ;
    xksi = 0. ;
    for (cs_lnum_t i = 0; i < 3; i++) {
      for (cs_lnum_t j = 0; j < 3; j++) {
        xeta += bij[i][j]*bij[j][i] ;
        for (cs_lnum_t k = 0; k < 3; k++)
          xksi += bij[i][j]*bij[j][k]*bij[k][i];
      }
    }

    inv[iloc][0] =  sqrt(-xeta/6.0);
    inv[iloc][1] =  cbrt(xksi/6.0);
  }

  BFT_FREE(rij);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute the Q-criterion from Hunt et. al over each cell of a specified
 *        volume region.
 *
 * \f[
 *    Q = \tens{\Omega}:\tens{\Omega} -
 *    \deviator{ \left(\tens{S} \right)}:\deviator{ \left(\tens{S} \right)}
 * \f]
 * where \f$\tens{\Omega}\f$ is the vorticity tensor and
 * \f$\deviator{ \left(\tens{S} \right)}\f$ the deviatoric of the rate of strain
 * tensor.
 *
 * \param[in]  n_loc_cells  number of cells
 * \param[in]  cell_ids     list of cells (0 to n-1)
 * \param[out] q_crit       Q-criterion over the specified volume region.
 */
/*----------------------------------------------------------------------------*/

void
cs_post_q_criterion(const cs_lnum_t  n_loc_cells,
                    const cs_lnum_t  cell_ids[],
                    cs_real_t        q_crit[])
{
  const cs_lnum_t n_cells_ext = cs_glob_mesh->n_cells_with_ghosts;

  cs_real_33_t *gradv;

  BFT_MALLOC(gradv, n_cells_ext, cs_real_33_t);

  bool use_previous_t = false;
  int inc = 1;
  cs_field_gradient_vector(CS_F_(vel),
                           use_previous_t,
                           inc,
                           gradv);

  for (cs_lnum_t i = 0; i < n_loc_cells; i++) {
    cs_lnum_t c_id = cell_ids[i];
    q_crit[i] = -1./6. * (   cs_math_sq(gradv[c_id][0][0])
                          +  cs_math_sq(gradv[c_id][1][1])
                          +  cs_math_sq(gradv[c_id][2][2]))
                - gradv[c_id][0][1]*gradv[c_id][1][0]
                - gradv[c_id][0][2]*gradv[c_id][2][0]
                - gradv[c_id][1][2]*gradv[c_id][2][1];
  }

  BFT_FREE(gradv);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute scalar flux on a specific boundary region.
 *
 * The flux is counted negatively through the normal.
 *
 * \param[in]   scalar_name    scalar name
 * \param[in]   n_loc_b_faces  number of selected boundary faces
 * \param[in]   b_face_ids     ids of selected boundary faces
 * \param[out]  b_face_flux    surface flux through selected faces
 */
/*----------------------------------------------------------------------------*/

void
cs_post_boundary_flux(const char       *scalar_name,
                      cs_lnum_t         n_loc_b_faces,
                      const cs_lnum_t   b_face_ids[],
                      cs_real_t         b_face_flux[])
{
  const cs_mesh_quantities_t *fvq = cs_glob_mesh_quantities;
  const cs_real_t *restrict b_face_surf = fvq->b_face_surf;

  cs_real_t normal[] = {0, 0, 0};

  cs_flux_through_surface(scalar_name,
                          normal,
                          n_loc_b_faces,
                          0,
                          b_face_ids,
                          NULL,
                          NULL,
                          b_face_flux,
                          NULL);

  if (b_face_ids != NULL) {
    for (cs_lnum_t i = 0; i < n_loc_b_faces; i++) {
      cs_lnum_t f_id = b_face_ids[i];
      b_face_flux[i] /= b_face_surf[f_id];
    }
  }
  else {
    for (cs_lnum_t f_id = 0; f_id < n_loc_b_faces; f_id++) {
      b_face_flux[f_id] /= b_face_surf[f_id];
    }
  }
}

/*----------------------------------------------------------------------------*/

END_C_DECLS
