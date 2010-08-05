!-------------------------------------------------------------------------------

!     This file is part of the Code_Saturne Kernel, element of the
!     Code_Saturne CFD tool.

!     Copyright (C) 1998-2009 EDF S.A., France

!     contact: saturne-support@edf.fr

!     The Code_Saturne Kernel is free software; you can redistribute it
!     and/or modify it under the terms of the GNU General Public License
!     as published by the Free Software Foundation; either version 2 of
!     the License, or (at your option) any later version.

!     The Code_Saturne Kernel is distributed in the hope that it will be
!     useful, but WITHOUT ANY WARRANTY; without even the implied warranty
!     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!     GNU General Public License for more details.

!     You should have received a copy of the GNU General Public License
!     along with the Code_Saturne Kernel; if not, write to the
!     Free Software Foundation, Inc.,
!     51 Franklin St, Fifth Floor,
!     Boston, MA  02110-1301  USA

!-------------------------------------------------------------------------------

subroutine memclg &
!================

 ( idbia0 , idbra0 ,                                              &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr ,                                     &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifinia , ifinra )

!===============================================================================
!  FONCTION
!  --------

!  GESTION MEMOIRE POUR LE CALCUL    DES DONNEES GEO
!             COMPLEMENTAIRES
!             MEMOIRE NON VOLATILE

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! idbia0           ! i  ! <-- ! number of first free position in ia            !
! idbra0           ! i  ! <-- ! number of first free position in ra            !
! ndim             ! i  ! <-- ! spatial dimension                              !
! ncelet           ! i  ! <-- ! number of extended (real + ghost) cells        !
! ncel             ! i  ! <-- ! number of cells                                !
! nfac             ! i  ! <-- ! number of interior faces                       !
! nfabor           ! i  ! <-- ! number of boundary faces                       !
! nfml             ! i  ! <-- ! number of families (group classes)             !
! nprfml           ! i  ! <-- ! number of properties per family (group class)  !
! nnod             ! i  ! <-- ! number of vertices                             !
! lndfac           ! i  ! <-- ! size of nodfac indexed array                   !
! lndfbr           ! i  ! <-- ! size of nodfbr indexed array                   !
! nideve, nrdeve   ! i  ! <-- ! sizes of idevel and rdevel arrays              !
! nituse, nrtuse   ! i  ! <-- ! sizes of ituser and rtuser arrays              !
! ifinia           ! i  ! --> ! number of first free position in ia (at exit)  !
! ifinra           ! i  ! --> ! number of first free position in ra (at exit)  !!__________________.____._____.________________________________________________.

!     TYPE : E (ENTIER), R (REEL), A (ALPHANUMERIQUE), T (TABLEAU)
!            L (LOGIQUE)   .. ET TYPES COMPOSES (EX : TR TABLEAU REEL)
!     MODE : <-- donnee, --> resultat, <-> Donnee modifiee
!            --- tableau de travail
!===============================================================================

implicit none

!===============================================================================
! Common blocks
!===============================================================================

include "paramx.f90"
include "pointe.f90"

!===============================================================================

! Arguments

integer idbia0 , idbra0
integer ndim   , ncelet , ncel , nfac , nfabor , nfml , nprfml
integer nnod   , lndfac , lndfbr
integer nideve , nrdeve , nituse , nrtuse
integer ifinia , ifinra

! Local variables

integer idebia ,idebra

!===============================================================================

!---> INITIALISATION

idebia = idbia0
idebra = idbra0

!---> PLACE MEMOIRE RESERVEE AVEC DEFINITION DE IFINIA IFINRA

ifinia = idebia

isrfan = idebra
isrfbn = isrfan + nfac
idist  = isrfbn + nfabor
idistb = idist  + nfac
ipond  = idistb + nfabor
idijpf = ipond  + nfac
idiipb = idijpf + nfac  *ndim
idofij = idiipb + nfabor*ndim
ifinra = idofij + nfac  *ndim


!---> VERIFICATION

CALL IASIZE('MEMCLG',IFINIA)
!     ==========

CALL RASIZE('MEMCLG',IFINRA)
!     ==========

return
end subroutine
