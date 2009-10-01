/*============================================================================
 *
 *     This file is part of the Code_Saturne Kernel, element of the
 *     Code_Saturne CFD tool.
 *
 *     Copyright (C) 1998-2009 EDF S.A., France
 *
 *     contact: saturne-support@edf.fr
 *
 *     The Code_Saturne Kernel is free software; you can redistribute it
 *     and/or modify it under the terms of the GNU General Public License
 *     as published by the Free Software Foundation; either version 2 of
 *     the License, or (at your option) any later version.
 *
 *     The Code_Saturne Kernel is distributed in the hope that it will be
 *     useful, but WITHOUT ANY WARRANTY; without even the implied warranty
 *     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with the Code_Saturne Kernel; if not, write to the
 *     Free Software Foundation, Inc.,
 *     51 Franklin St, Fifth Floor,
 *     Boston, MA  02110-1301  USA
 *
 *============================================================================*/

#ifndef __CS_TCPUMX_H__
#define __CS_TCPUMX_H__

/*============================================================================
 * Query time allocated to this process (useful mainly under PBS)
 *============================================================================*/

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_base.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*============================================================================
 * Public function prototypes for Fortran API
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Query CPU time allocated to this process
 *
 * Fortran interface:
 *
 * SUBROUTINE TCPUMX (TPS   , RET)
 * *****************
 *
 * DOUBLE PRECISION TPS        : <-- : remaining time (default: 7 days)
 * INTEGER          RET        : <-- : return code:
 *                             :     :  -1: error
 *                             :     :   0: no limit using this method
 *                             :     :   1: CPU limit determined
 *----------------------------------------------------------------------------*/

void CS_PROCF (tcpumx, TCPUMX) (double  *tps,
                                int     *ret);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* _CS_TCPUMX_H_ */
