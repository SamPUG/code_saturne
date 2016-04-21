#ifndef __CS_CDOVB_DIFFUSION_H__
#define __CS_CDOVB_DIFFUSION_H__

/*============================================================================
 * Build discrete stiffness matrices and handled boundary conditions for the
 * diffusion term in CDO vertex-based schemes
 *============================================================================*/

/*
  This file is part of Code_Saturne, a general-purpose CFD tool.

  Copyright (C) 1998-2016 EDF S.A.

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

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_cdo.h"
#include "cs_cdo_connect.h"
#include "cs_cdo_local.h"
#include "cs_cdo_quantities.h"
#include "cs_hodge.h"
#include "cs_param.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*============================================================================
 * Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definitions
 *============================================================================*/

typedef struct _cs_cdovb_diff_t  cs_cdovb_diff_t;

/*============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief   Initialize a builder structure used to build the stiffness matrix
 *
 * \param[in] connect      pointer to a cs_cdo_connect_t struct.
 * \param[in] is_uniform   diffusion tensor is uniform ? (true or false)
 * \param[in] h_info       cs_param_hodge_t struct.
 * \param[in] bc_enforce   type of boundary enforcement for Dirichlet values
 *
 * \return a pointer to a new allocated cs_cdovb_diffusion_builder_t struc.
 */
/*----------------------------------------------------------------------------*/

cs_cdovb_diff_t *
cs_cdovb_diffusion_builder_init(const cs_cdo_connect_t       *connect,
                                bool                          is_uniform,
                                const cs_param_hodge_t        h_info,
                                const cs_param_bc_enforce_t   bc_enforce);

/*----------------------------------------------------------------------------*/
/*!
 * \brief   Free a cs_cdovb_diff_t structure
 *
 * \param[in, out ] diff   pointer to a cs_cdovb_diff_t struc.
 *
 * \return  NULL
 */
/*----------------------------------------------------------------------------*/

cs_cdovb_diff_t *
cs_cdovb_diffusion_builder_free(cs_cdovb_diff_t   *diff);

/*----------------------------------------------------------------------------*/
/*!
 * \brief   Get the related Hodge builder structure
 *
 * \param[in]  diff   pointer to a cs_cdovb_diff_t structure
 *
 * \return  a pointer to a cs_hodge_builder_t structure
 */
/*----------------------------------------------------------------------------*/

cs_hodge_builder_t *
cs_cdovb_diffusion_get_hodge_builder(cs_cdovb_diff_t   *diff);

/*----------------------------------------------------------------------------*/
/*!
 * \brief   Define the local (cellwise) stiffness matrix
 *
 * \param[in]      quant       pointer to a cs_cdo_quantities_t struct.
 * \param[in]      lm          cell-wise connectivity and quantitites
 * \param[in]      tensor      3x3 matrix attached to the diffusion property
 * \param[in, out] diff        auxiliary structure used to build the diff. term
 *
 * \return a pointer to a local stiffness matrix
 */
/*----------------------------------------------------------------------------*/

cs_locmat_t *
cs_cdovb_diffusion_build_local(const cs_cdo_quantities_t   *quant,
                               const cs_cdo_locmesh_t      *lm,
                               const cs_real_3_t           *tensor,
                               cs_cdovb_diff_t             *diff);

/*----------------------------------------------------------------------------*/
/*!
 * \brief   Compute the gradient of the conforming reconstruction in each
 *          p_{ef,c} tetrahedron
 *
 * \param[in]      quant       pointer to a cs_cdo_quantities_t struct.
 * \param[in]      lm          cell-wise connectivity and quantitites
 * \param[in]      pdi         cellwise values of the discrete potential
 * \param[in, out] diff        auxiliary structure used to build the diff. term
 * \param[in, out] grd_lv_conf gradient of the conforming reconstruction
 */
/*----------------------------------------------------------------------------*/

void
cs_cdovb_diffusion_get_grd_lvconf(const cs_cdo_quantities_t   *quant,
                                  const cs_cdo_locmesh_t      *lm,
                                  const double                *pdi,
                                  cs_cdovb_diff_t             *diff,
                                  double                      *grd_lv_conf);

/*----------------------------------------------------------------------------*/
/*!
 * \brief   Define the local (cellwise) "normal trace gradient" matrix taking
 *          into account Dirichlet BCs by a weak enforcement using Nitsche
 *          technique (symmetrized or not)
 *
 * \param[in]       f_id      face id (a border face attached to a Dir. BC)
 * \param[in]       quant     pointer to a cs_cdo_quantities_t struct.
 * \param[in]       lm        pointer to a cs_cdo_locmesh_t struct.
 * \param[in]       matpty    3x3 matrix related to the diffusion property
 * \param[in, out]  diff      auxiliary structure used to build the diff. term
 * \param[in, out]  ls        cell-wise structure sotring the local system
 */
/*----------------------------------------------------------------------------*/

void
cs_cdovb_diffusion_weak_bc(cs_lnum_t                    f_id,
                           const cs_cdo_quantities_t   *quant,
                           cs_cdo_locmesh_t            *lm,
                           const cs_real_t              matpty[3][3],
                           cs_cdovb_diff_t             *diff,
                           cs_cdo_locsys_t             *ls);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_CDOVB_DIFFUSION_H__ */
