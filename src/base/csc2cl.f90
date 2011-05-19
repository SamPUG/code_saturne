!-------------------------------------------------------------------------------

!     This file is part of the Code_Saturne Kernel, element of the
!     Code_Saturne CFD tool.

!     Copyright (C) 1998-2011 EDF S.A., France

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

subroutine csc2cl &
!================

 ( idbia0 , idbra0 ,                                              &
   nvar   , nscal  ,                                              &
   nvcp   , nvcpto , nfbcpl , nfbncp ,                            &
   icodcl , itrifb , itypfb ,                                     &
   lfbcpl , lfbncp ,                                              &
   ia     ,                                                       &
   dt     , rtp    , rtpa   , propce , propfa , propfb ,          &
   coefa  , coefb  , rcodcl ,                                     &
   w1     , w2     , w3     , w4     , w5     , w6     , coefu  , &
   rvcpfb , pndcpl , dofcpl ,                                     &
   ra     )

!===============================================================================
! Purpose:
! --------

! Translation of the "itypfb(*, *) = icscpl" condition.

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! idbia0           ! i  ! <-- ! number of first free position in ia            !
! idbra0           ! i  ! <-- ! number of first free position in ra            !
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! icodcl           ! te ! --> ! boundary condition code at boundary faces      !
!  (nfabor, nvar)  !    !     ! = 1   -> dirichlet                             !
!                  !    !     ! = 3   -> flux density                          !
!                  !    !     ! = 4   -> sliding and u.n=0 (velocity)          !
!                  !    !     ! = 5   -> friction and u.n=0 (velocity)         !
!                  !    !     ! = 9   -> free inlet/outlet (inlet velocity     !
!                  !    !     !  possibly fixed)                               !
!                  !    !     ! = 10  -> free inlet/outlet (possible inlet     !
!                  !    !     !  volocity not fixed: prescribe a Dirichlet     !
!                  !    !     !  value for scalars k, eps, scal in addition to !
!                  !    !     !  the usual Neumann                             !
! itrifb           ! ia ! <-- ! indirection for boundary faces ordering        !
! itypfb           ! ia ! --> ! boundary face types                            !
! ia(*)            ! ia ! --- ! main integer work array                        !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! rtp, rtpa        ! ra ! <-- ! calculated variables at cell centers           !
!  (ncelet, *)     !    !     !  (at current and previous time steps)          !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! propfa(nfac, *)  ! ra ! <-- ! physical properties at interior face centers   !
! propfb(nfabor, *)! ra ! <-- ! physical properties at boundary face centers   !
! coefa, coefb     ! ra ! <-- ! boundary conditions                            !
!  (nfabor, *)     !    !     !                                                !
! rcodcl           ! tr ! --> ! value of boundary conditions at boundary faces !
!  (nfabor, nvar)  !    !     ! rcodcl(1) = Dirichlet value                    !
!                  !    !     ! rcodcl(2) = ext. exchange coefficient value    !
!                  !    !     !  (infinite if no exchange)                     !
!                  !    !     ! rcodcl(3) = value of the flux density          !
!                  !    !     !  (negative if gain) in w/m2                    !
!                  !    !     ! for velocities:   (vistl+visct)*gradu          !
!                  !    !     ! for pressure:                dt*gradp          !
!                  !    !     ! for scalars:                                   !
!                  !    !     !        cp*(viscls+visct/sigmas)*gradt          !
! w1,2,3,4,5,6     ! ra ! --- ! work arrays                                    !
!  (ncelet)        !    !     !  (computation of pressure gradient)            !
! ra(*)            ! ra ! --- ! main real work array                           !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use pointe
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use period
use cplsat
use mesh

!===============================================================================

implicit none

! Arguments

integer          idbia0 , idbra0
integer          nvar   , nscal
integer          nvcp   , nvcpto
integer          nfbcpl , nfbncp

integer          icodcl(nfabor,nvar)
integer          lfbcpl(nfbcpl)  , lfbncp(nfbncp)
integer          itrifb(nfabor), itypfb(nfabor)
integer          ia(*)

double precision dt(ncelet), rtp(ncelet,*), rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfa(nfac,*), propfb(nfabor,*)
double precision coefa(nfabor,*), coefb(nfabor,*)
double precision rcodcl(nfabor,nvar,3)
double precision w1(ncelet),w2(ncelet),w3(ncelet)
double precision w4(ncelet),w5(ncelet),w6(ncelet)
double precision coefu(nfabor,ndim)
double precision rvcpfb(nfbcpl,nvcpto), pndcpl(nfbcpl)
double precision dofcpl(3,nfbcpl)
double precision ra(*)

! Local variables

integer          idebia, idebra
integer          ifac, iel,isou
integer          inc, iccocg, iclvar, nswrgp, imligp
integer          iwarnp, ivar
integer          ipt
integer          iii

double precision epsrgp, climgp, extrap
double precision xp
double precision xip   , xiip  , yiip  , ziip
double precision xjp
double precision xipf, yipf, zipf, ipf

double precision xif, yif, zif, xopf, yopf, zopf
double precision gradi, pondj, flumab

!===============================================================================


idebia = idbia0
idebra = idbra0


!===============================================================================
! 1.  Translation of the coupling to boundary conditions
!===============================================================================

! Reminder: variables are received in the order of VARPOS;
! loopin on variables is thus sufficient.

do ivar = 1, nvcp

  ! --- Compute gradient of variable if it is interpolated.
  !       Exchanges for parallelism and periodicity have already been
  !       done in CSCPFB. Non need to do them again.

  inc    = 1
  iccocg = 1

  iclvar = iclrtp(ivar,icoef)
  nswrgp = nswrgr(ivar)
  imligp = imligr(ivar)
  iwarnp = iwarni(ivar)
  epsrgp = epsrgr(ivar)
  climgp = climgr(ivar)
  extrap = extrag(ivar)

  call grdcel                                                     &
  !==========
 ( ivar   , imrgra , inc    , iccocg , nswrgp , imligp ,          &
   iwarnp , nfecra ,                                              &
   epsrgp , climgp , extrap ,                                     &
   ia     ,                                                       &
   rtp(1,ivar) , coefa(1,iclvar) , coefb(1,iclvar) ,              &
   w1     , w2     , w3     ,                                     &
!        ------   ------   ------
   ra     )


  ! For a specific face to face coupling, geometric assumptions are made

  if (ifaccp.eq.1) then


    do ipt = 1, nfbcpl

      ifac = lfbcpl(ipt)
      iel  = ifabor(ifac)

      ! Information for current instance interpolated at I'
      xiip = diipb(1,ifac)
      yiip = diipb(2,ifac)
      ziip = diipb(3,ifac)

      xif = cdgfbo(1,ifac) -xyzcen(1,iel)
      yif = cdgfbo(2,ifac) -xyzcen(2,iel)
      zif = cdgfbo(3,ifac) -xyzcen(3,iel)

      xipf = cdgfbo(1,ifac)-xiip - xyzcen(1,iel)
      yipf = cdgfbo(2,ifac)-yiip - xyzcen(2,iel)
      zipf = cdgfbo(3,ifac)-ziip - xyzcen(3,iel)

      ipf = sqrt(xipf**2+yipf**2+zipf**2)

      xopf = dofcpl(1,ipt)
      yopf = dofcpl(2,ipt)
      zopf = dofcpl(3,ipt)

      if (ivar.eq.ipr) then

        ! --- We want to prescribe a Direchlet for pressure so as to conserve
        !     the pressure gradient through the coupling and remain consistent
        !     with the resolution of the pressure gradient on an orthogonal mesh.

        xip = rtp(iel,ivar) + (w1(iel)*xiip + w2(iel)*yiip + w3(iel)*ziip)

      else if (ivar.eq.iu.or.ivar.eq.iv.or.ivar.eq.iw) then

        ! --- For all other variables, we want to prescribe a Dirichlet matching
        !     the convective fluxes at the center. We resrve a choice between
        !     UPWIND, SOLU, and CENTERED. Only the centered case respects the diffusion
        !     at the domain's interior faces. For UPWIND and SOLU, the decentering
        !     is done here and in bilsc2.f90 for coupled faces.

        ! -- UPWIND

        !        xip =  rtp(iel,ivar)

        ! -- SOLU

        !        xip =  rtp(iel,ivar) + (w1(iel)*xif + w2(iel)*yif + w3(iel)*zif)

        ! -- CENTERED

        xip =  rtp(iel,ivar) + w1(iel)*xiip + w2(iel)*yiip + w3(iel)*ziip

      else

        ! -- UPWIND

        !        xip =  rtp(iel,ivar)

        ! -- SOLU

        !        xip =  rtp(iel,ivar) + (w1(iel)*xif + w2(iel)*yif + w3(iel)*zif)

        ! -- CENTERED

        xip =  rtp(iel,ivar) + (w1(iel)*xiip + w2(iel)*yiip + w3(iel)*ziip)

      endif

      ! -- We need alpha_ij for centered interpolation and flumab for decentering

      pondj = pndcpl(ipt)
      flumab = propfb(ifac,ipprob(ifluma(iu)))

      ! Information received from distant instance at J'/O'
      xjp = rvcpfb(ipt,ivar)


      itypfb(ifac)  = icscpl

      if (ivar.eq.ipr) then

        icodcl(ifac,ivar  ) = 1
        rcodcl(ifac,ivar,1) = (1.d0-pondj)*xjp + pondj*xip + p0

      else if (ivar.eq.iu.or.ivar.eq.iv.or.ivar.eq.iw) then

        icodcl(ifac,ivar  ) = 1

        ! -- DECENTERED (SOLU or UPWIND)

        !        if (flumab.ge.0.d0) then
        !          rcodcl(ifac,ivar,1) = xip
        !        else
        !          rcodcl(ifac,ivar,1) = xjp
        !        endif

        ! -- CENTERED

        rcodcl(ifac,ivar,1) = (1.d0-pondj)*xjp + pondj*xip

      else

        icodcl(ifac,ivar  ) = 1

        ! -- DECENTERED (SOLU or UPWIND)

        !        if(flumab.ge.0.d0) then
        !          rcodcl(ifac,ivar,1) = xip
        !        else
        !          rcodcl(ifac,ivar,1) = xjp
        !        endif

        ! -- CENTERED

        rcodcl(ifac,ivar,1) = (1.d0-pondj)*xjp + pondj*xip

      endif

    enddo

    ! For a generic coupling, no assumption can be made

  else


    ! --- Translation in terms of boundary conditions for located boundary faces
    !     --> Dirichlet BC type

    do ipt = 1, nfbcpl

      ifac = lfbcpl(ipt)
      iel  = ifabor(ifac)

      ! Information from local instance interpolated at I'
      xiip = diipb(1,ifac)
      yiip = diipb(2,ifac)
      ziip = diipb(3,ifac)

      xif = cdgfbo(1,ifac) -xyzcen(1,iel)
      yif = cdgfbo(2,ifac) -xyzcen(2,iel)
      zif = cdgfbo(3,ifac) -xyzcen(3,iel)

      xipf = cdgfbo(1,ifac)-xiip - xyzcen(1,iel)
      yipf = cdgfbo(2,ifac)-yiip - xyzcen(2,iel)
      zipf = cdgfbo(3,ifac)-ziip - xyzcen(3,iel)

      ipf = sqrt(xipf**2+yipf**2+zipf**2)

      xopf = dofcpl(1,ipt)
      yopf = dofcpl(2,ipt)
      zopf = dofcpl(3,ipt)

      ! Local information interpolated at I'/O'

      xip =  rtp(iel,ivar)                                          &
        + (w1(iel)*(xiip+xopf) + w2(iel)*(yiip+yopf) + w3(iel)*(ziip+zopf))

      ! Information received from distant instance at J'/O'
      xjp = rvcpfb(ipt,ivar)


      gradi = (w1(iel)*xipf+w2(iel)*yipf+w3(iel)*zipf)/ipf

      itypfb(ifac)  = icscpl

      if(ivar.ne.ipr) then
        icodcl(ifac,ivar  ) = 1
        rcodcl(ifac,ivar,1) = 0.5d0*(xip+xjp)
      else
        icodcl(ifac,ivar  ) = 3
        rcodcl(ifac,ivar,3) = -0.5d0*dt(iel)*(gradi+xjp)
      endif


    enddo

  endif

  ! --- Non-located boundary faces
  !     --> Homogeneous Neuman BC type

  do ipt = 1, nfbncp

    ifac = lfbncp(ipt)

    itypfb(ifac)  = icscpl

    icodcl(ifac,ivar  ) = 3
    rcodcl(ifac,ivar,3) = 0.d0

  enddo

enddo


!----
! Formats
!----

!----
! End
!----

return
end subroutine
