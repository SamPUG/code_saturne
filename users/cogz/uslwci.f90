!-------------------------------------------------------------------------------

!VERS


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

subroutine uslwci &
!================

 ( idbia0 , idbra0 ,                                              &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml , maxelt , lstelt , &
   ipnfac , nodfac , ipnfbr , nodfbr ,                            &
   idevel , ituser , ia     ,                                     &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtp    , propce , propfa , propfb , coefa  , coefb  , &
   rdevel , rtuser , ra     )

!===============================================================================
! FONCTION :
! --------

! INITIALISATION DES VARIABLES DE CALCUL
!    POUR LA PHYSIQUE PARTICULIERE : COMBUSTION GAZ MODELE LWC
!    PENDANT DE USINIV.F

! Cette routine est appelee en debut de calcul (suite ou non)
!     dans la boucle en temps avant la resolution des scalaires

! Elle permet d'INITIALISER ou de MODIFIER (pour les calculs suite)
!     les variables de calcul.


! On a repris a titre d'exemple dans cette routine utilisateur
!     l'initialisation choisie par defaut.


! Les proprietes physiques sont accessibles dans le tableau
!     PROPCE (prop au centre), PROPFA (aux faces internes),
!     PROPFB (prop aux faces de bord)
!     Ainsi,
!      PROPCE(IEL,IPPROC(IROM  (IPHAS))) designe ROM   (IEL ,IPHAS)
!      PROPCE(IEL,IPPROC(IVISCL(IPHAS))) designe VISCL (IEL ,IPHAS)
!      PROPCE(IEL,IPPROC(ICP   (IPHAS))) designe CP    (IEL ,IPHAS)
!      PROPCE(IEL,IPPROC(IVISLS(ISCAL))) designe VISLS (IEL ,ISCAL)

!      PROPFA(IFAC,IPPROF(IFLUMA(IVAR ))) designe FLUMAS(IFAC,IVAR)

!      PROPFB(IFAC,IPPROB(IROM  (IPHAS))) designe ROMB  (IFAC,IPHAS)
!      PROPFB(IFAC,IPPROB(IFLUMA(IVAR ))) designe FLUMAB(IFAC,IVAR)

! LA MODIFICATION DES PROPRIETES PHYSIQUES (ROM, VISCL, VISCLS, CP)
!     SE FERA EN STANDARD DANS LE SOUS PROGRAMME PPPHYV
!     ET PAS ICI


! Cells identification
! ====================

! Cells may be identified using the 'getcel' subroutine.
! The syntax of this subroutine is described in the 'usclim' subroutine,
! but a more thorough description can be found in the user guide.


! Arguments
!__________________.____._____.________________________________________________.
!    nom           !type!mode !                   role                         !
!__________________!____!_____!________________________________________________!
! idbia0           ! e  ! <-- ! numero de la 1ere case libre dans ia           !
! idbra0           ! e  ! <-- ! numero de la 1ere case libre dans ra           !
! ndim             ! e  ! <-- ! dimension de l'espace                          !
! ncelet           ! e  ! <-- ! nombre d'elements halo compris                 !
! ncel             ! e  ! <-- ! nombre d'elements actifs                       !
! nfac             ! e  ! <-- ! nombre de faces internes                       !
! nfabor           ! e  ! <-- ! nombre de faces de bord                        !
! nfml             ! e  ! <-- ! nombre de familles d entites                   !
! nprfml           ! e  ! <-- ! nombre de proprietese des familles             !
! nnod             ! e  ! <-- ! nombre de sommets                              !
! lndfac           ! e  ! <-- ! longueur du tableau nodfac (optionnel          !
! lndfbr           ! e  ! <-- ! longueur du tableau nodfbr (optionnel          !
! ncelbr           ! e  ! <-- ! nombre d'elements ayant au moins une           !
!                  !    !     ! face de bord                                   !
! nvar             ! e  ! <-- ! nombre total de variables                      !
! nscal            ! e  ! <-- ! nombre total de scalaires                      !
! nphas            ! e  ! <-- ! nombre de phases                               !
! nideve nrdeve    ! e  ! <-- ! longueur de idevel rdevel                      !
! nituse nrtuse    ! e  ! <-- ! longueur de ituser rtuser                      !
! ifacel           ! te ! <-- ! elements voisins d'une face interne            !
! (2, nfac)        !    !     !                                                !
! ifabor           ! te ! <-- ! element  voisin  d'une face de bord            !
! (nfabor)         !    !     !                                                !
! ifmfbr           ! te ! <-- ! numero de famille d'une face de bord           !
! (nfabor)         !    !     !                                                !
! ifmcel           ! te ! <-- ! numero de famille d'une cellule                !
! (ncelet)         !    !     !                                                !
! iprfml           ! te ! <-- ! proprietes d'une famille                       !
! nfml  ,nprfml    !    !     !                                                !
! maxelt           !  e ! <-- ! nb max d'elements (cell,fac,fbr)               !
! lstelt(maxelt) te ! --- ! tableau de travail                             !
! ipnfac           ! te ! <-- ! position du premier noeud de chaque            !
!   (lndfac)       !    !     !  face interne dans nodfac (optionnel)          !
! nodfac           ! te ! <-- ! connectivite faces internes/noeuds             !
!   (nfac+1)       !    !     !  (optionnel)                                   !
! ipnfbr           ! te ! <-- ! position du premier noeud de chaque            !
!   (lndfbr)       !    !     !  face de bord dans nodfbr (optionnel)          !
! nodfbr           ! te ! <-- ! connectivite faces de bord/noeuds              !
!   (nfabor+1)     !    !     !  (optionnel)                                   !
! idevel(nideve    ! te ! <-- ! tab entier complementaire developemt           !
! ituser(nituse    ! te ! <-- ! tab entier complementaire utilisateur          !
! ia(*)            ! tr ! --- ! macro tableau entier                           !
! xyzcen           ! tr ! <-- ! point associes aux volumes de control          !
! (ndim,ncelet     !    !     !                                                !
! surfac           ! tr ! <-- ! vecteur surface des faces internes             !
! (ndim,nfac)      !    !     !                                                !
! surfbo           ! tr ! <-- ! vecteur surface des faces de bord              !
! (ndim,nfabor)    !    !     !                                                !
! cdgfac           ! tr ! <-- ! centre de gravite des faces internes           !
! (ndim,nfac)      !    !     !                                                !
! cdgfbo           ! tr ! <-- ! centre de gravite des faces de bord            !
! (ndim,nfabor)    !    !     !                                                !
! xyznod           ! tr ! <-- ! coordonnes des noeuds (optionnel)              !
! (ndim,nnod)      !    !     !                                                !
! volume           ! tr ! <-- ! volume d'un des ncelet elements                !
! (ncelet          !    !     !                                                !
! dt(ncelet)       ! tr ! <-- ! valeur du pas de temps                         !
! rtp              ! tr ! <-- ! variables de calcul au centre des              !
! (ncelet,*)       !    !     !    cellules                                    !
! propce           ! tr ! <-- ! proprietes physiques au centre des             !
! (ncelet,*)       !    !     !    cellules                                    !
! propfa           ! tr ! <-- ! proprietes physiques au centre des             !
!  (nfac,*)        !    !     !    faces internes                              !
! propfb           ! tr ! <-- ! proprietes physiques au centre des             !
!  (nfabor,*)      !    !     !    faces de bord                               !
! coefa coefb      ! tr ! <-- ! conditions aux limites aux                     !
!  (nfabor,*)      !    !     !    faces de bord                               !
! rdevel(nrdeve    ! tr ! <-- ! tab reel complementaire developemt             !
! rtuser(nrtuse    ! tr ! <-- ! tab reel complementaire utilisateur            !
! ra(*)            ! tr ! --- ! macro tableau reel                             !
!__________________!____!_____!________________________________________________!

!     TYPE : E (ENTIER), R (REEL), A (ALPHANUMERIQUE), T (TABLEAU)
!            L (LOGIQUE)   .. ET TYPES COMPOSES (EX : TR TABLEAU REEL)
!     MODE : <-- donnee, --> resultat, <-> Donnee modifiee
!            --- tableau de travail
!===============================================================================

implicit none

!===============================================================================
!     DONNEES EN COMMON
!===============================================================================

include "paramx.h"
include "pointe.h"
include "numvar.h"
include "optcal.h"
include "cstphy.h"
include "cstnum.h"
include "entsor.h"
include "parall.h"
include "period.h"
include "ppppar.h"
include "ppthch.h"
include "coincl.h"
include "cpincl.h"
include "ppincl.h"

!===============================================================================

integer          idbia0 , idbra0
integer          ndim   , ncelet , ncel   , nfac   , nfabor
integer          nfml   , nprfml
integer          nnod   , lndfac , lndfbr , ncelbr
integer          nvar   , nscal  , nphas
integer          nideve , nrdeve , nituse , nrtuse

integer          ifacel(2,nfac) , ifabor(nfabor)
integer          ifmfbr(nfabor) , ifmcel(ncelet)
integer          iprfml(nfml,nprfml), maxelt, lstelt(maxelt)
integer          ipnfac(nfac+1), nodfac(lndfac)
integer          ipnfbr(nfabor+1), nodfbr(lndfbr)
integer          idevel(nideve), ituser(nituse), ia(*)

double precision xyzcen(ndim,ncelet)
double precision surfac(ndim,nfac), surfbo(ndim,nfabor)
double precision cdgfac(ndim,nfac), cdgfbo(ndim,nfabor)
double precision xyznod(ndim,nnod), volume(ncelet)
double precision dt(ncelet), rtp(ncelet,*), propce(ncelet,*)
double precision propfa(nfac,*), propfb(nfabor,*)
double precision coefa(nfabor,*), coefb(nfabor,*)
double precision rdevel(nrdeve), rtuser(nrtuse), ra(*)

! VARIABLES LOCALES

integer          idebia, idebra
integer          iel, mode, igg, iphas, izone
double precision hinit, coefg(ngazgm)
double precision sommqf, sommqt, sommq, tentm, fmelm


character*80     chaine
integer          iscal, ivar, ii
double precision valmax, valmin

!===============================================================================


! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================

if(1.eq.1) return

!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

!===============================================================================
! 0. IMPRESSION DE CONTROLE
!===============================================================================

write(nfecra,9001)

!===============================================================================
! 1.  INITIALISATION VARIABLES LOCALES
!===============================================================================

idebia = idbia0
idebra = idbra0

do igg = 1, ngazgm
  coefg(igg) = zero
enddo

iphas  = 1

!===============================================================================
! 2. INITIALISATION DES INCONNUES :
!      UNIQUEMENT SI ON NE FAIT PAS UNE SUITE
!===============================================================================

if ( isuite.eq.0 ) then

! ----- Calculs preliminaires : Fraction de melange, T, H
!     (la valeur NOZAPM est utilisee pour inclure les aspects parall)

  sommqf = zero
  sommq  = zero
  sommqt = zero
  do izone = 1, nozapm
    sommqf = sommqf + qimp(izone)*fment(izone)
    sommqt = sommqt + qimp(izone)*tkent(izone)
    sommq  = sommq  + qimp(izone)
  enddo

  if(abs(sommq).gt.epzero) then
    fmelm = sommqf / sommq
    tentm = sommqt / sommq
  else
    fmelm = zero
    tentm = t0(iphas)
  endif

! ----- Enthalpie du melange HINIT

  if ( ippmod(icolwc).eq.1 .or. ippmod(icolwc).eq.3               &
                             .or. ippmod(icolwc).eq.5 ) then
    coefg(1) = fmelm
    coefg(2) = (1.d0-fmelm)
    coefg(3) = zero
    mode     = -1
    call cothht                                                   &
    !==========
      ( mode   , ngazg , ngazgm  , coefg  ,                       &
        npo    , npot   , th     , ehgazg ,                       &
        hinit  , tentm )
  endif

  do iel = 1, ncel


! ---- initialisation de f et y
!          on initialise y=0 pour avoir des gazs brules
!          et enflamer le melange

    rtp(iel,isca(iyfm))  = 0.0d0*fmelm
    rtp(iel,isca(ifm))   = 0.d0*fmelm

! ---- initialisation des variances

    rtp(iel,isca(iyfp2m)) = zero
    rtp(iel,isca(ifp2m))  = zero

! -----  initialisation de la covariance pour NDIRAC >= 3

    if ( ippmod(icolwc).ge. 2 ) then
      rtp(iel,isca(icoyfp))   = zero
    endif

! ----- Enthalpie du melange

    if ( ippmod(icolwc).eq.1 .or. ippmod(icolwc).eq.3             &
                               .or. ippmod(icolwc).eq.5 ) then
      rtp(iel,isca(ihm)) = hinit
    endif

  enddo

! ---> Impressions de controle des valeurs entrees par l'utlisateur

    write(nfecra,2000)

    do ii  = 1, nscapp
      iscal = iscapp(ii)
      ivar  = isca(iscal)
      valmax = -grand
      valmin =  grand
      do iel = 1, ncel
        valmax = max(valmax,rtp(iel,ivar))
        valmin = min(valmin,rtp(iel,ivar))
      enddo
      if ( irangp.ge.0 ) then
        call parmax(valmax)
        call parmin(valmin)
      endif

      chaine = nomvar(ipprtp(ivar))
      write(nfecra,2010)chaine(1:8),valmin,valmax
    enddo
    write(nfecra,2020)

endif

!     Initialisation des scalaires

!----
! FORMATS
!----

 9001 format(                                                           &
'                                                             ',/,&
'  uslwci : Initialisation des variables par l''utilisateur   ',/,&
'                                                             ',/)

 2000 format(                                                           &
'                                                             ',/,&
' ----------------------------------------------------------- ',/,&
'                                                             ',/,&
'                                                             ',/,&
' ** INITIALISATION DES VARIABLES PROPRES AU GAZ (FL PRE LWC) ',/,&
'    -------------------------------------------------------- ',/,&
'           1 SEUL PASSAGE                                    ',/,&
' ---------------------------------                           ',/,&
'  Variable  Valeur min  Valeur max                           ',/,&
' ---------------------------------                           '  )

 2010 format(                                                           &
 2x,     a8,      e12.4,      e12.4                              )

 2020 format(                                                           &
' ---------------------------------                           ',/)


!----
! FIN
!----

return
end subroutine
