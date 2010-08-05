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

subroutine lagent &
!================

 ( idbia0 , idbra0 ,                                              &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndnod , lndfac , lndfbr , ncelbr ,                   &
   nvar   , nscal  , nphas  ,                                     &
   nbpmax , nvp    , nvp1   , nvep   , nivep  ,                   &
   ntersl , nvlsta , nvisbr ,                                     &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml ,                   &
   ipnfac , nodfac , ipnfbr , nodfbr ,                            &
   itycel , icocel ,                                              &
   itypfb , itrifb , ifrlag , itepa  ,                            &
   idevel , ituser , ia     ,                                     &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   surfbn , dt     , rtpa   , propce , propfa , propfb ,          &
   coefa  , coefb  ,                                              &
   ettp   , tepa   , vagaus , auxl   , w1     , w2     , w3     , &
   rdevel , rtuser , ra     )

!===============================================================================
! FONCTION :
! ----------

!   SOUS-PROGRAMME DU MODULE LAGRANGIEN :
!   -------------------------------------

!   Gestion de l'injection des particules dans le domaine de calcul

!     1. initialisation par l'utilisateur via USLAG2
!        des classes de particules et du type d'interaction
!        particule/face de frontiere.

!     2. injection des particules dans le domaine : initialisation
!        des tableau ETTP, ITEPA(IP,JISOR) et TEPA(IP,JRPOI).

!     3. modification des conditions d'injection des particules :
!        retouche des ETTP, ITEPA(IP,JISOR) et TEPA(IP,JRPOI).

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
! lndnod           ! e  !  ->           ! longueur du tableau icocel
! lndfac           ! i  ! <-- ! size of nodfac indexed array                   !
! lndfbr           ! i  ! <-- ! size of nodfbr indexed array                   !
! ncelbr           ! i  ! <-- ! number of cells with faces on boundary         !
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! nphas            ! i  ! <-- ! number of phases                               !
! nbpmax           ! e  ! <-- ! nombre max de particulies autorise             !
! nvp              ! e  ! <-- ! nombre de variables particulaires              !
! nvp1             ! e  ! <-- ! nvp sans position, vfluide, vpart              !
! nvep             ! e  ! <-- ! nombre info particulaires (reels)              !
! nivep            ! e  ! <-- ! nombre info particulaires (entiers)            !
! ntersl           ! e  ! <-- ! nbr termes sources de couplage retour          !
! nvlsta           ! e  ! <-- ! nombre de var statistiques lagrangien          !
! nvisbr           ! e  ! <-- ! nombre de statistiques aux frontieres          !
! nideve, nrdeve   ! i  ! <-- ! sizes of idevel and rdevel arrays              !
! nituse, nrtuse   ! i  ! <-- ! sizes of ituser and rtuser arrays              !
! ifacel(2, nfac)  ! ia ! <-- ! interior faces -> cells connectivity           !
! ifabor(nfabor)   ! ia ! <-- ! boundary faces -> cells connectivity           !
! ifmfbr(nfabor)   ! ia ! <-- ! boundary face family numbers                   !
! ifmcel(ncelet)   ! ia ! <-- ! cell family numbers                            !
! iprfml           ! te ! <-- ! proprietes d'une famille                       !
!  (nfml,nprfml    !    !     !                                                !
! ipnfac           ! te ! <-- ! position du premier noeud de chaque            !
!   (lndfac)       !    !     !  face interne dans nodfac                      !
! nodfac           ! te ! <-- ! connectivite faces internes/noeuds             !
!   (nfac+1)       !    !     !                                                !
! ipnfbr           ! te ! <-- ! position du premier noeud de chaque            !
!   (lndfbr)       !    !     !  face de bord dans nodfbr                      !
! nodfbr           ! te ! <-- ! connectivite faces de bord/noeuds              !
!   (nfabor+1)     !    !     !                                                !
! icocel           ! te ! <-- ! connectivite cellules -> faces                 !
! (lndnod)         !    !     !    face de bord si numero negatif              !
! itycel           ! te ! <-- ! connectivite cellules -> faces                 !
! (ncelet+1)       !    !     !    pointeur du tableau icocel                  !
! itypfb           ! ia ! <-- ! boundary face types                            !
!  (nfabor, nphas) !    !     !                                                !
! itrifb(nfabor    ! te ! <-- ! tab d'indirection pour tri des faces           !
!  nphas)          !    !     !                                                !
! ifrlag           ! te ! --> ! numero de zone de la face de bord              !
! (nfabor)         !    !     !  pour le module lagrangien                     !
! itepa            ! te ! --> ! info particulaires (entiers)                   !
! (nbpmax,nivep    !    !     !   (cellule de la particule,...)                !
! idevel(nideve)   ! ia ! <-> ! integer work array for temporary development   !
! ituser(nituse)   ! ia ! <-> ! user-reserved integer work array               !
! ia(*)            ! ia ! --- ! main integer work array                        !
! xyzcen           ! ra ! <-- ! cell centers                                   !
!  (ndim, ncelet)  !    !     !                                                !
! surfac           ! ra ! <-- ! interior faces surface vectors                 !
!  (ndim, nfac)    !    !     !                                                !
! surfbo           ! ra ! <-- ! boundary faces surface vectors                 !
!  (ndim, nfabor)  !    !     !                                                !
! cdgfac           ! ra ! <-- ! interior faces centers of gravity              !
!  (ndim, nfac)    !    !     !                                                !
! cdgfbo           ! ra ! <-- ! boundary faces centers of gravity              !
!  (ndim, nfabor)  !    !     !                                                !
! xyznod           ! tr ! <-- ! coordonnes des noeuds                          !
! (ndim,nnod)      !    !     !                                                !
! volume(ncelet    ! tr ! <-- ! volume d'un des ncelet elements                !
! surfbn(nfabor    ! tr ! <-- ! surface des faces de bord                      !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! rtpa             ! tr ! <-- ! variables de calcul au centre des              !
! (ncelet,*)       !    !     !    cellules (instant prec ou                   !
!                  !    !     !    instant courant si ntcabs = 1)              !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! propfa(nfac, *)  ! ra ! <-- ! physical properties at interior face centers   !
! propfb(nfabor, *)! ra ! <-- ! physical properties at boundary face centers   !
! coefa, coefb     ! ra ! <-- ! boundary conditions                            !
!  (nfabor, *)     !    !     !                                                !
! rdevel(nrdeve)   ! ra ! <-> ! real work array for temporary development      !
! rtuser(nrtuse)   ! ra ! <-> ! user-reserved real work array                  !
! ettp             ! tr ! <-- ! tableaux des variables liees                   !
!  (nbpmax,nvp)    !    !     !   aux particules etape courante                !
! tepa             ! tr ! <-- ! info particulaires (reels)                     !
! (nbpmax,nvep)    !    !     !   (poids statistiques,...)                     !
! vagaus           ! tr ! --> ! variables aleatoires gaussiennes               !
!(nbpmax,nvgaus    !    !     !                                                !
! auxl(nbpmax,3    ! tr ! --- ! tableau de travail                             !
! w1..w3(ncelet    ! tr ! --- ! tableaux de travail                            !
! ra(*)            ! ra ! --- ! main real work array                           !
!__________________!____!_____!________________________________________________!

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
include "numvar.f90"
include "optcal.f90"
include "entsor.f90"
include "cstnum.f90"
include "cstphy.f90"
include "pointe.f90"
include "period.f90"
include "parall.f90"
include "lagpar.f90"
include "lagran.f90"
include "ppppar.f90"
include "ppthch.f90"
include "ppincl.f90"
include "cpincl.f90"
include "radiat.f90"
include "ihmpre.f90"

!===============================================================================

! Arguments

integer          idbia0 , idbra0
integer          ndim   , ncelet , ncel   , nfac   , nfabor
integer          nfml   , nprfml
integer          nnod   , lndnod , lndfac , lndfbr , ncelbr
integer          nvar   , nscal  , nphas
integer          nbpmax , nvp    , nvp1   , nvep  , nivep
integer          ntersl , nvlsta , nvisbr
integer          nideve , nrdeve , nituse , nrtuse
integer          ifacel(2,nfac) , ifabor(nfabor)
integer          ifmfbr(nfabor) , ifmcel(ncelet)
integer          iprfml(nfml,nprfml)
integer          ipnfac(nfac+1) , nodfac(lndfac)
integer          ipnfbr(nfabor+1) , nodfbr(lndfbr)
integer          itypfb(nfabor,nphas) , itrifb(nfabor,nphas)
integer          icocel(lndnod) , itycel(ncelet+1)
integer          itepa(nbpmax,nivep) , ifrlag(nfabor)
integer          idevel(nideve) , ituser(nituse)
integer          ia(*)

double precision xyzcen(ndim,ncelet)
double precision surfac(ndim,nfac) , surfbo(ndim,nfabor)
double precision cdgfac(ndim,nfac) , cdgfbo(ndim,nfabor)
double precision xyznod(ndim,nnod) , volume(ncelet)
double precision surfbn(nfabor)
double precision dt(ncelet) , rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfa(nfac,*), propfb(nfabor,*)
double precision coefa(nfabor,*), coefb(nfabor,*)
double precision ettp(nbpmax,nvp) , tepa(nbpmax,nvep)
double precision vagaus(nbpmax,*)
double precision auxl(nbpmax,3)
double precision w1(ncelet) ,  w2(ncelet) ,  w3(ncelet)
double precision rdevel(nrdeve) , rtuser(nrtuse)
double precision ra(*)

! Local variables

integer          idebia, idebra
integer          ifinia, ifinra

integer          iel , ifac , iphas , ip , nb , nc, ii, ifvu
integer          iiwork , iok , n1 , nd , icha
integer          npt , nfin , npar1  , npar2 , mode , idvar
integer          maxelt, idbia1, ils

double precision vn1 , vn2 , vn3 , pis6 , d3
double precision dmasse , rd(1) , aa
double precision xxpart , yypart , zzpart
double precision tvpart , uupart , vvpart , wwpart
double precision ddpart , ttpart
double precision surf   , volp , vitp

!===============================================================================

!===============================================================================
! 0.  GESTION MEMOIRE
!===============================================================================

idebia = idbia0
idebra = idbra0

!===============================================================================
! 1. INITIALISATION
!===============================================================================

! Init aberrante pour forcer l'utilisateur a mettre sa valeur

iphas = ilphas

pis6 = pi / 6.d0

do nb = 1, nflagm
  iusncl(nb) = 0
  iusclb(nb) = 0
enddo

do nb = 1, nflagm
  do nc = 1, nclagm
    do nd = 1,ndlagm
      ruslag(nc,nb,nd) = 0.d0
    enddo
    do nd = 1,ndlaim
      iuslag(nc,nb,nd) = 0
    enddo
  enddo
enddo

do nb = 1, nflagm
  do nc = 1, nclagm

    iuslag(nc,nb,ijnbp) =  0
    iuslag(nc,nb,ijfre) =  0
    iuslag(nc,nb,iclst) =  0
    iuslag(nc,nb,ijuvw) = -2
    iuslag(nc,nb,ijprtp) = -2
    iuslag(nc,nb,ijprdp) = -2
    iuslag(nc,nb,ijprpd) = -2

    ruslag(nc,nb,iuno)  = -grand
    ruslag(nc,nb,iupt)  = -grand
    ruslag(nc,nb,ivpt)  = -grand
    ruslag(nc,nb,iwpt)  = -grand
    ruslag(nc,nb,ipoit) = -grand

    ruslag(nc,nb,idpt)  = -grand
    ruslag(nc,nb,ivdpt) = -grand
    ruslag(nc,nb,iropt) = -grand

    if ( iphyla.eq.1 ) then

!    Thermique

      if ( itpvar.eq.1 ) then
        ruslag(nc,nb,itpt)  = -grand
        ruslag(nc,nb,icpt)  = -grand
        ruslag(nc,nb,iepsi) = -grand
      endif

    else if ( iphyla .eq. 2 ) then

!    Charbon
!    (REM : le diametre du coeur retrecissant est calcule dans lagich.F)

      iuslag(nc,nb,inuchl) = 0
      ruslag(nc,nb,ihpt)   = -grand
      ruslag(nc,nb,imcht)  = -grand
      ruslag(nc,nb,imckt)  = -grand
      ruslag(nc,nb,icpt)   = -grand

    endif

  enddo
enddo

do ifac = 1,nfabor
  ifrlag(ifac) = 0
enddo

!    Mise a zero des debits pour chaque zone de bord

do nb = 1,nflagm
  deblag(nb) = 0.d0
enddo

!===============================================================================
! 2. Initialisation utilisateur par classe et par frontiere
!===============================================================================

maxelt = max(ncelet,nfac,nfabor)
ils    = idebia
idbia1 = ils + maxelt
call iasize('lagent', idbia1)
!==========

if (iihmpr.eq.1) then
  call uilag2                                                     &
  !==========
 ( nfabor, nozppm, nclagm, nflagm, nbclst,                        &
   ientrl, isortl, idepo1, idepo2, idepo3,                        &
   idepfa, iencrl, irebol, iphyla,                                &
   ijnbp,  ijfre,  iclst,  ijuvw,  iuno,   iupt,   ivpt,   iwpt,  &
   ijprpd, ipoit,  idebt,  ijprdp, idpt,   ivdpt,                 &
   iropt,  ijprtp, itpt,   icpt,   iepsi,                         &
   ihpt,   inuchl, imcht,  imckt,                                 &
   ichcor, cp2ch,  diam20, rho0ch, xashch,                        &
   ifrlag, iusncl, iusclb, iuslag, ruslag     )
endif

call uslag2                                                       &
!==========
 ( idbia1 , idebra ,                                              &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nbpmax , nvp    , nvp1   , nvep   , nivep  ,                   &
   ntersl , nvlsta , nvisbr ,                                     &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml , maxelt , ia(ils), &
   ipnfac , nodfac , ipnfbr , nodfbr ,                            &
   itypfb , itrifb , itepa  , ifrlag ,                            &
   idevel , ituser , ia     ,                                     &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtpa   , propce , propfa , propfb ,                   &
   coefa  , coefb  ,                                              &
   ettp   , tepa   ,                                              &
   rdevel , rtuser , ra     )

!===============================================================================
! 3. Controles
!===============================================================================

iok = 0

! --> Les faces doivent toutes appartenir a une zone frontiere

do ifac = 1, nfabor
  if(ifrlag(ifac).le.0 .or. ifrlag(ifac).gt.nflagm) then
    iok = iok + 1
    write(nfecra,1000) ifac,nflagm,ifrlag(ifac)
  endif
enddo

if (iok.gt.0) then
  call csexit (1)
  !==========
endif

! --> On construit une liste des numeros des zones frontieres.

nfrlag = 0
do ifac = 1, nfabor
  ifvu = 0
  do ii = 1, nfrlag
    if (ilflag(ii).eq.ifrlag(ifac)) then
      ifvu = 1
    endif
  enddo
  if(ifvu.eq.0) then
    nfrlag = nfrlag + 1
    if(nfrlag.le.nflagm) then
      ilflag(nfrlag) = ifrlag(ifac)
    else
      write(nfecra,1001) nfrlag
      WRITE(NFECRA,'(I10)') (ILFLAG(II),II=1,NFRLAG)
      call csexit (1)
      !==========
    endif
  endif
enddo

! --> Nombre de classes.

do ii = 1,nfrlag
  nb = ilflag(ii)
  if (iusncl(nb).lt.0 .or. iusncl(nb).gt.nclagm) then
    iok = iok + 1
    write(nfecra,1010) nb,nclagm,iusncl(nb)
  endif
enddo

! --> Nombre de particules.

do ii = 1,nfrlag
  nb = ilflag(ii)
  do nc = 1,iusncl(nb)
    if ( iuslag(nc,nb,ijnbp).lt.0 .or.                            &
         iuslag(nc,nb,ijnbp).gt.nbpmax ) then
      iok = iok + 1
      write(nfecra,1020) nc,nb,nbpmax,iuslag(nc,nb,ijnbp)
    endif
  enddo
enddo

!    Verification des classes de particules : Uniquement un warning

if (nbclst.gt.0 ) then
  do ii = 1,nfrlag
    nb = ilflag(ii)
    do nc = 1,iusncl(nb)
      if (iuslag(nc,nb,iclst).le.0      .or.                      &
          iuslag(nc,nb,iclst).gt.nbclst        ) then
        write(nfecra,1021) nc,nb,nbclst,iuslag(nc,nb,iclst)
      endif
    enddo
  enddo
endif

! --> Frequence d'injection.

do ii = 1,nfrlag
  nb = ilflag(ii)
  do nc = 1, iusncl(nb)
    if (iuslag(nc,nb,ijfre).lt.0) then
      iok = iok + 1
      write(nfecra,1030) nb,nc,iuslag(nc,nb,ijfre)
    endif
  enddo
enddo

! --> Conditions au bord.

do ii = 1,nfrlag
  nb = ilflag(ii)
  if ( iusclb(nb).ne.ientrl .and. iusclb(nb).ne.isortl .and.      &
       iusclb(nb).ne.irebol .and. iusclb(nb).ne.idepo1 .and.      &
       iusclb(nb).ne.idepo2 .and. iusclb(nb).ne.idepo3 .and.      &
       iusclb(nb).ne.iencrl .and. iusclb(nb).ne.jbord1 .and.      &
       iusclb(nb).ne.jbord2 .and. iusclb(nb).ne.jbord3 .and.      &
       iusclb(nb).ne.jbord4 .and. iusclb(nb).ne.jbord5 .and.      &
       iusclb(nb).ne.idepfa ) then
    iok = iok + 1
    write(nfecra,1040) nb
  endif
enddo

do ii = 1,nfrlag
  nb = ilflag(ii)
  if (iusclb(nb).eq.idepo2 .and. iensi2.ne.1) then
    iok = iok + 1
    write(nfecra,1041) nb
  endif
enddo

do ii = 1,nfrlag
  nb = ilflag(ii)
  if (iusclb(nb).eq.iencrl .and. iphyla.ne.2) then
    iok = iok + 1
    write(nfecra,1042) nb
  endif
enddo

do ii = 1,nfrlag
  nb = ilflag(ii)
  if (iusclb(nb).eq.iencrl .and. iencra.ne.1) then
    iok = iok + 1
    write(nfecra,1043) nb
  endif
enddo

! --> Type de condition pour le taux de presence.

do ii = 1, nfrlag
  nb = ilflag(ii)
  do nc = 1, iusncl(nb)
    if ( iuslag(nc,nb,ijprpd).lt.1 .or.                           &
         iuslag(nc,nb,ijprpd).gt.2      ) then
      iok = iok + 1
      write(nfecra,1053) nb, nc, iuslag(nc,nb,ijprpd)
    endif
  enddo
enddo

! --> Type de condition pour la vitesse.

do ii = 1, nfrlag
  nb = ilflag(ii)
  do nc = 1, iusncl(nb)
    if ( iuslag(nc,nb,ijuvw).lt.-1 .or.                           &
         iuslag(nc,nb,ijuvw).gt.2      ) then
      iok = iok + 1
      write(nfecra,1050) nb,nc,iuslag(nc,nb,ijuvw)
    endif
  enddo
enddo

! --> Type de condition pour le diametre.

do ii = 1, nfrlag
  nb = ilflag(ii)
  do nc = 1, iusncl(nb)
    if ( iuslag(nc,nb,ijprdp).lt.1 .or.                           &
         iuslag(nc,nb,ijprdp).gt.2      ) then
      iok = iok + 1
      write(nfecra,1051) nb, nc, iuslag(nc,nb,ijprdp)
    endif
  enddo
enddo

! --> Type de condition pour le diametre.

if ( iphyla.eq.1 .and.                                            &
       (itpvar.eq.1 .or. idpvar.eq.1 .or. impvar.eq.1) ) then
  do ii = 1, nfrlag
    nb = ilflag(ii)
    do nc = 1, iusncl(nb)
      if ( iuslag(nc,nb,ijprtp).lt.1 .or.                         &
           iuslag(nc,nb,ijprtp).gt.2      ) then
        iok = iok + 1
        write(nfecra,1052) nb, nc, iuslag(nc,nb,ijprtp)
      endif
    enddo
  enddo
endif

! --> Poids statistiques

do ii = 1, nfrlag
  nb = ilflag(ii)
  do nc = 1, iusncl(nb)
    if (ruslag(nc,nb,ipoit).le.0.d0) then
      iok = iok + 1
      write(nfecra,1055) nb, nc, ruslag(nc,nb,ipoit)
    endif
  enddo
enddo

! --> Debit massique de particule

do ii = 1, nfrlag
  nb = ilflag(ii)
  do nc = 1, iusncl(nb)
    if (ruslag(nc,nb,idebt).lt.0.d0) then
      iok = iok + 1
      write(nfecra,1056) nb, nc, ruslag(nc,nb,idebt)
    endif
  enddo
enddo
do ii = 1, nfrlag
  nb = ilflag(ii)
  do nc = 1, iusncl(nb)
    if (ruslag(nc,nb,idebt).gt.0.d0 .and.                         &
        iuslag(nc,nb,ijnbp).eq.0         ) then
      iok = iok + 1
      write(nfecra,1057) nb, nc, ruslag(nc,nb,idebt),             &
                                 iuslag(nc,nb,ijnbp)
    endif
  enddo
enddo

! --> Proprietes des particules : le diametre, son ecart-type, et rho

do ii = 1, nfrlag
  nb = ilflag(ii)
  do nc = 1, iusncl(nb)
    if (ruslag(nc,nb,iropt).lt.0.d0 .or.                          &
        ruslag(nc,nb,idpt) .lt.0.d0 .or.                          &
        ruslag(nc,nb,ivdpt).lt.0.d0       ) then
      iok = iok + 1
      write(nfecra,1060) nb, nc,                                  &
                         ruslag(nc,nb,iropt),                     &
                         ruslag(nc,nb,idpt),                      &
                         ruslag(nc,nb,ivdpt)
    endif
  enddo
enddo

do ii = 1, nfrlag
  nb = ilflag(ii)
  do nc = 1, iusncl(nb)
    if ( ruslag(nc,nb,idpt).lt.3.d0*ruslag(nc,nb,ivdpt) ) then
      iok = iok + 1
      write(nfecra,1065) nb, nc,                                  &
        ruslag(nc,nb,idpt)-3.d0*ruslag(nc,nb,ivdpt)
    endif
  enddo
enddo

! --> Proprietes des particules : Temperature et CP

if (iphyla.eq.1 .and. itpvar.eq.1) then

  do ii = 1, nfrlag
    nb = ilflag(ii)
    do nc = 1, iusncl(nb)
      if (ruslag(nc,nb,icpt)  .lt.0.d0   .or.                     &
          ruslag(nc,nb,itpt)  .lt.tkelvn       ) then
        iok = iok + 1
        write(nfecra,1070)                                        &
        iphyla, itpvar, nb, nc,                                   &
        ruslag(nc,nb,itpt), ruslag(nc,nb,icpt)
      endif
    enddo
  enddo

endif

! --> Proprietes des particules : Emissivite

if (iphyla.eq.1 .and. itpvar.eq.1 .and. iirayo.gt.0) then

  do ii = 1, nfrlag
    nb = ilflag(ii)
    do nc = 1, iusncl(nb)
      if (ruslag(nc,nb,iepsi) .lt.0.d0 .or.                       &
          ruslag(nc,nb,iepsi) .gt.1.d0      ) then
        iok = iok + 1
        write(nfecra,1075)                                        &
        iphyla, itpvar, nb, nc, ruslag(nc,nb,iepsi)
      endif
    enddo
  enddo

endif

! Charbon

if (iphyla.eq.2) then

! --> Numero du charbon

  do ii = 1, nfrlag
    nb = ilflag(ii)
    do nc = 1, iusncl(nb)
      if (iuslag(nc,nb,inuchl).lt.0.d0                            &
          .and.  iuslag(nc,nb,inuchl).gt.ncharb) then
        iok = iok + 1
        write(nfecra,1080) nb, nc, ncharb, iuslag(nc,nb,inuchl)
      endif
    enddo
  enddo

! --> Proprietes des particules de Charbon.

  do ii = 1, nfrlag
    nb = ilflag(ii)
    do nc = 1, iusncl(nb)
      if (ruslag(nc,nb,ihpt)  .lt.0.d0 .or.                       &
          ruslag(nc,nb,icpt)  .lt.0.d0 .or.                       &
          ruslag(nc,nb,imcht) .lt.0.d0 .or.                       &
          ruslag(nc,nb,imckt) .lt.0.d0  ) then
        iok = iok + 1
        write(nfecra,1090)                                        &
        iphyla, nb, nc,                                           &
        ruslag(nc,nb,ihpt),  ruslag(nc,nb,icpt),                  &
        ruslag(nc,nb,imcht), ruslag(nc,nb,imckt)
      endif
    enddo
  enddo
endif

! --> Stop si erreur.

if(iok.gt.0) then
  call csexit (1)
  !==========
endif


!===============================================================================
! 4. Transformation des donnees utilisateur
!===============================================================================

! --> Injection des part 1ere iter seulement si freq d'injection nulle

do ii = 1, nfrlag
  nb = ilflag(ii)
  do nc = 1, iusncl(nb)
    if (iuslag(nc,nb,ijfre).eq.0 .and. iplas.eq.1) then
      iuslag(nc,nb,ijfre) = ntcabs
    endif
    if (iuslag(nc,nb,ijfre).eq.0 .and. iplas.gt.1) then
      iuslag(nc,nb,ijfre) = ntcabs+1
    endif
  enddo
enddo

! --> Calcul du nombre de particules a injecter pour cette iteration

nbpnew = 0
dnbpnw = 0.d0

!     Dans le cas ou on a un taux de presence impose dans une zone,
!     on corrige IUSLAG(NC,NB,IJNBP) donne dans USLAG2 qui n'a
!     pas de sens puisque l'on injecte 1 particule par maille

do ii = 1,nfrlag
  nb = ilflag(ii)
!       pour chaque classe :
  do nc = 1, iusncl(nb)
!         si de nouvelles particules doivent entrer :
    if (mod(ntcabs,iuslag(nc,nb,ijfre)).eq.0) then

      if ( iuslag(nc,nb,ijprpd) .eq. 2 ) then
        iuslag(nc,nb,ijnbp)=0
        do ifac = 1,nfabor
          if (ifrlag(ifac).eq.nb) then
            iuslag(nc,nb,ijnbp)=iuslag(nc,nb,ijnbp)+1
          endif
        enddo
      endif
    endif
  enddo
enddo

do ii = 1,nfrlag
  nb = ilflag(ii)
  do nc = 1, iusncl(nb)
    if (mod(ntcabs,iuslag(nc,nb,ijfre)).eq.0) then
      nbpnew = nbpnew + iuslag(nc,nb,ijnbp)
    endif
  enddo
enddo

! --> Limite du nombre de particules a NBPMAX

if ( (nbpart+nbpnew).gt.nbpmax ) then
  write(nfecra,3000) nbpart,nbpnew,nbpmax
  nbpnew = 0
endif

! --> Si pas de new particules alors RETURN

if (nbpnew.eq.0) return

! --> Tirage aleatoire des positions des NBPNEW nouvelles particules
!   au niveau des zones de bord et reperage des cellules correspondantes

!   initialisation du compteur de nouvelles particules

npt = nbpart

!     On reserve d'abord la memoire si on a de nouvelles particules
!       on garde IIWORK jusqu'a lagnwc

iiwork = idebia
ifinia = iiwork + nbpmax
ifinra = idebra
CALL IASIZE('LAGENT',IFINIA)
!==========

!     Ensuite, on regarde ou on les met

!     pour chaque zone de bord :
do ii = 1,nfrlag
  nb = ilflag(ii)
!       pour chaque classe :
  do nc = 1, iusncl(nb)
!         si de nouvelles particules doivent entrer :
    if (mod(ntcabs,iuslag(nc,nb,ijfre)).eq.0) then

      if ( iuslag(nc,nb,ijprpd) .eq. 1 ) then

      call lagnew                                                 &
      !==========
  ( ifinia , ifinra ,                                             &
    ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml ,&
    nnod   , lndnod , lndfac , lndfbr , ncelbr ,                  &
    nbpmax , nvp    , nvp1   , nvep   , nivep  ,                  &
    npt    , nbpnew , iuslag(nc,nb,ijnbp)      ,                  &
    nideve , nrdeve , nituse , nrtuse ,                           &
    nb     ,                                                      &
    ifacel , ifabor , ifmfbr , ifmcel , iprfml ,                  &
    ipnfac , nodfac , ipnfbr , nodfbr ,                           &
    ifrlag , itepa(1,jisor)  , ia(iiwork)      ,                  &
    idevel , ituser , ia     ,                                    &
    xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume ,&
    surfbn , ettp   ,                                             &
    rdevel , rtuser , ra     )

      elseif ( iuslag(nc,nb,ijprpd) .eq. 2 ) then

        call lagnpr                                               &
        !==========
  ( ifinia , ifinra ,                                             &
    ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml ,&
    nnod   , lndnod , lndfac , lndfbr , ncelbr ,                  &
    nbpmax , nvp    , nvp1   , nvep   , nivep  ,                  &
    npt    , nbpnew , iuslag(nc,nb,ijnbp)      ,                  &
    nideve , nrdeve , nituse , nrtuse ,                           &
    nb     ,                                                      &
    ifacel , ifabor , ifmfbr , ifmcel , iprfml ,                  &
    ipnfac , nodfac , ipnfbr , nodfbr ,                           &
    ifrlag , itepa(1,jisor)  , ia(iiwork)      ,                  &
    idevel , ituser , ia     ,                                    &
    xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume ,&
    surfbn , ettp   ,                                             &
    rdevel , rtuser , ra     )
      endif

    endif
  enddo
enddo

!-->TEST DE CONTROLE (NE PAS MODIFIER)

if ( (nbpart+nbpnew).ne.npt ) then
  write(nfecra,3010) nbpnew, npt-nbpart
  call csexit (1)
  !==========
endif

!--> Injection en continu des particules

if ( injcon.eq.1 ) then

!   reinitialisation du compteur de nouvelles particules

  npt = nbpart

!       pour chaque zone de bord:

  do ii = 1,nfrlag
    nb = ilflag(ii)

!         pour chaque classe :

    do nc = 1, iusncl(nb)

!           si de nouvelles particules doivent entrer :
      if ( mod(ntcabs,iuslag(nc,nb,ijfre)).eq.0 ) then

        call lagnwc                                               &
        !==========
  ( ifinia , ifinra ,                                             &
    ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml ,&
    nnod   , lndnod , lndfac , lndfbr , ncelbr ,                  &
    nbpmax , nvp    , nvp1   , nvep   , nivep  ,                  &
    npt    , nbpnew , iuslag(nc,nb,ijnbp)      ,                  &
    nideve , nrdeve , nituse , nrtuse ,                           &
    ifacel , ifabor , ifmfbr , ifmcel , iprfml ,                  &
    ipnfac , nodfac , ipnfbr , nodfbr ,                           &
    itycel , icocel ,                                             &
    ifrlag , itepa(1,jisor)  , ia(iiwork) ,                       &
    idevel , ituser , ia     ,                                    &
    xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume ,&
    surfbn , ettp   ,                                             &
    rdevel , rtuser , ra     )

      endif

    enddo
  enddo

endif

!-->TEST DE CONTROLE (NE PAS MODIFIER)

if ( (nbpart+nbpnew).ne.npt ) then
  write(nfecra,3010) nbpnew, npt-nbpart
  call csexit (1)
  !==========
endif


!   reinitialisation du compteur de nouvelles particules

npt = nbpart

!     pour chaque zone de bord:
do ii = 1,nfrlag
  nb = ilflag(ii)

!       pour chaque classe :
  do nc = 1, iusncl(nb)

!         si de nouvelles particules doivent entrer :
    if (mod(ntcabs,iuslag(nc,nb,ijfre)).eq.0) then

      do ip = npt+1 , npt+iuslag(nc,nb,ijnbp)
        iel = itepa(ip,jisor)
        ifac = ia(iiwork+ip-1)

!-->COMPOSANTES DE LA VITESSE DES PARTICULES

!             si composantes de la vitesse imposee :
        if (iuslag(nc,nb,ijuvw).eq.1) then
          ettp(ip,jup) = ruslag(nc,nb,iupt)
          ettp(ip,jvp) = ruslag(nc,nb,ivpt)
          ettp(ip,jwp) = ruslag(nc,nb,iwpt)

!             si norme de la vitesse imposee :
        else if (iuslag(nc,nb,ijuvw).eq.0) then
          aa = -1.d0 / surfbn(ifac)
          vn1 = surfbo(1,ifac) * aa
          vn2 = surfbo(2,ifac) * aa
          vn3 = surfbo(3,ifac) * aa
          ettp(ip,jup) = vn1 * ruslag(nc,nb,iuno)
          ettp(ip,jvp) = vn2 * ruslag(nc,nb,iuno)
          ettp(ip,jwp) = vn3 * ruslag(nc,nb,iuno)

!             si vitesse du fluide vu :
        else if (iuslag(nc,nb,ijuvw).eq.-1) then
          ettp(ip,jup) = rtpa(iel,iu(iphas))
          ettp(ip,jvp) = rtpa(iel,iv(iphas))
          ettp(ip,jwp) = rtpa(iel,iw(iphas))

!             si profil de vitesse impose :
        else if (iuslag(nc,nb,ijuvw).eq.2) then

         idvar = 1
         xxpart = ettp(ip,jxp)
         yypart = ettp(ip,jyp)
         zzpart = ettp(ip,jzp)

         call uslapr                                              &
         !==========
 ( idebia , idebra ,                                              &
   idvar  , iel    , nb     , nc     ,                            &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nbpmax , nvp    , nvp1   , nvep   , nivep  ,                   &
   ntersl , nvlsta , nvisbr ,                                     &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml ,                   &
   ipnfac , nodfac , ipnfbr , nodfbr ,                            &
   itypfb , itrifb , itepa  , ifrlag ,                            &
   idevel , ituser , ia     ,                                     &
   xxpart , yypart , zzpart ,                                     &
   tvpart , uupart , vvpart , wwpart , ddpart , ttpart ,          &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtpa   , propce , propfa , propfb ,                   &
   coefa  , coefb  ,                                              &
   ettp   , tepa   ,                                              &
   rdevel , rtuser , ra     )

          ettp(ip,jup) = uupart
          ettp(ip,jvp) = vvpart
          ettp(ip,jwp) = wwpart

        endif

!-->Vitesse du fluide vu

        ettp(ip,juf) = rtpa(iel,iu(iphas))
        ettp(ip,jvf) = rtpa(iel,iv(iphas))
        ettp(ip,jwf) = rtpa(iel,iw(iphas))

!--> TEMPS DE SEJOUR

        tepa(ip,jrtsp) = 0.d0

!--> Diametre

!             si diametre constant imposee :
        if (iuslag(nc,nb,ijprdp).eq.1) then
          if (ruslag(nc,nb,ivdpt) .gt. 0.d0) then
            n1 = 1
            call normalen(n1,rd)
            ettp(ip,jdp) = ruslag(nc,nb,idpt)                     &
                         + rd(1) * ruslag(nc,nb,ivdpt)

!    On verifie qu'on obtient un diam�tre dans la gamme des 99,7%

            d3 = 3.d0 * ruslag(nc,nb,ivdpt)
            if (ettp(ip,jdp).lt.ruslag(nc,nb,idpt)-d3)            &
              ettp(ip,jdp)= ruslag(nc,nb,idpt)
            if (ettp(ip,jdp).gt.ruslag(nc,nb,idpt)+d3)            &
              ettp(ip,jdp)= ruslag(nc,nb,idpt)
          else
            ettp(ip,jdp) = ruslag(nc,nb,idpt)
          endif

!             si profil pour le diametre  :
        else if (iuslag(nc,nb,ijprdp).eq.2) then

          idvar = 2
          xxpart = ettp(ip,jxp)
          yypart = ettp(ip,jyp)
          zzpart = ettp(ip,jzp)

          call uslapr                                             &
          !==========
 ( idebia , idebra ,                                              &
   idvar  , iel    , nb     , nc     ,                            &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nbpmax , nvp    , nvp1   , nvep   , nivep  ,                   &
   ntersl , nvlsta , nvisbr ,                                     &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml ,                   &
   ipnfac , nodfac , ipnfbr , nodfbr ,                            &
   itypfb , itrifb , itepa  , ifrlag ,                            &
   idevel , ituser , ia     ,                                     &
   xxpart , yypart , zzpart ,                                     &
   tvpart , uupart , vvpart , wwpart , ddpart , ttpart ,          &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtpa   , propce , propfa , propfb ,                   &
   coefa  , coefb  ,                                              &
   ettp   , tepa   ,                                              &
   rdevel , rtuser , ra     )

          ettp(ip,jdp) = ddpart

        endif

!--> Autres variables : masse, ... en fonction de la physique

        d3 = ettp(ip,jdp) * ettp(ip,jdp) * ettp(ip,jdp)

        if (nbclst.gt.0) then
          itepa(ip,jclst) = iuslag(nc,nb,iclst)
        endif

        if ( iphyla.eq.0 .or. iphyla.eq.1 ) then

          ettp(ip,jmp) = ruslag(nc,nb,iropt) * pis6 * d3

          if ( iphyla.eq.1 .and. itpvar.eq.1 ) then

!             si Temperature constante imposee :
            if (iuslag(nc,nb,ijprtp).eq.1) then
              ettp(ip,jtp) = ruslag(nc,nb,itpt)
!             si profil pour la temperature :
            else if (iuslag(nc,nb,ijprtp).eq.2) then

              idvar = 3
              xxpart = ettp(ip,jxp)
              yypart = ettp(ip,jyp)
              zzpart = ettp(ip,jzp)

              call uslapr                                         &
              !==========
 ( idebia , idebra ,                                              &
   idvar  , iel    , nb     , nc     ,                            &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nbpmax , nvp    , nvp1   , nvep   , nivep  ,                   &
   ntersl , nvlsta , nvisbr ,                                     &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml ,                   &
   ipnfac , nodfac , ipnfbr , nodfbr ,                            &
   itypfb , itrifb , itepa  , ifrlag ,                            &
   idevel , ituser , ia     ,                                     &
   xxpart , yypart , zzpart ,                                     &
   tvpart , uupart , vvpart , wwpart , ddpart , ttpart ,          &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtpa   , propce , propfa , propfb ,                   &
   coefa  , coefb  ,                                              &
   ettp   , tepa   ,                                              &
   rdevel , rtuser , ra     )

              ettp(ip,jtp) = ttpart

            endif

            if ( ippmod(icp3pl).ge.0 .or.                         &
                 ippmod(icpl3c).ge.0 .or.                         &
                 ippmod(icfuel).ge.0      ) then

              ettp(ip,jtf) = propce(iel,ipproc(itemp1)) -tkelvi

            else if ( ippmod(icod3p).ge.0 .or.                    &
                      ippmod(icoebu).ge.0 .or.                    &
                      ippmod(ielarc).ge.0 .or.                    &
                      ippmod(ieljou).ge.0      ) then

              ettp(ip,jtf) = propce(iel,ipproc(itemp)) -tkelvi

! Kelvin
            else if ( iscsth(iscalt(iphas)).eq.1 ) then

              ettp(ip,jtf) = rtpa(iel,isca(iscalt(iphas))) -tkelvi

! Celsius
            else if ( iscsth(iscalt(iphas)).eq.-1 ) then

              ettp(ip,jtf) = rtpa(iel,isca(iscalt(iphas)))

            else if ( iscsth(iscalt(iphas)).eq.2 ) then

              mode = 1
              call usthht(mode, rtpa(iel,isca(iscalt(iphas))),    &
                          ettp(ip,jtf))

            endif

            ettp(ip,jcp) = ruslag(nc,nb,icpt)
            tepa(ip,jreps) = ruslag(nc,nb,iepsi)

          endif

        else if ( iphyla.eq.2 ) then

          itepa(ip,jinch)  = iuslag(nc,nb,inuchl)
          ettp(ip,jhp) = ruslag(nc,nb,ihpt)
          ettp(ip,jtf) = propce(iel,ipproc(itemp1)) - tkelvi
          ettp(ip,jcp) = ruslag(nc,nb,icpt)

          ettp(ip,jmch) = ruslag(nc,nb,imcht)
          ettp(ip,jmck) = ruslag(nc,nb,imckt)

          tepa(ip,jrdck) = ettp(ip,jdp)
          tepa(ip,jrd0p) = ettp(ip,jdp)

          icha = itepa(ip,jinch)
          ettp(ip,jmp) = ettp(ip,jmch)                            &
                       + ettp(ip,jmck)                            &
             + xashch(icha) * pis6 * d3 * rho0ch(icha)

        endif

!--> POIDS STATISTIQUE

        if (iuslag(nc,nb,ijprpd).eq.1) then
          tepa(ip,jrpoi) = ruslag(nc,nb,ipoit)
        else if (iuslag(nc,nb,ijprpd).eq.2) then

          idvar = 0
          xxpart = ettp(ip,jxp)
          yypart = ettp(ip,jyp)
          zzpart = ettp(ip,jzp)

          call uslapr                                             &
          !==========
 ( idebia , idebra ,                                              &
   idvar  , iel    , nb     , nc     ,                            &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nbpmax , nvp    , nvp1   , nvep   , nivep  ,                   &
   ntersl , nvlsta , nvisbr ,                                     &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml ,                   &
   ipnfac , nodfac , ipnfbr , nodfbr ,                            &
   itypfb , itrifb , itepa  , ifrlag ,                            &
   idevel , ituser , ia     ,                                     &
   xxpart , yypart , zzpart ,                                     &
   tvpart , uupart , vvpart , wwpart , ddpart , ttpart ,          &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtpa   , propce , propfa , propfb ,                   &
   coefa  , coefb  ,                                              &
   ettp   , tepa   ,                                              &
   rdevel , rtuser , ra     )

          volp = pis6*d3
          surf = sqrt( surfbo(1,ifac)*surfbo(1,ifac)              &
                      +surfbo(2,ifac)*surfbo(2,ifac)              &
                      +surfbo(3,ifac)*surfbo(3,ifac) )
          vitp = sqrt( ettp(ip,jup)*ettp(ip,jup)                  &
                      +ettp(ip,jvp)*ettp(ip,jvp)                  &
                      +ettp(ip,jwp)*ettp(ip,jwp) )
          tepa(ip,jrpoi) =tvpart*(surf*vitp*dtp)/volp

         endif

      enddo

      npt = npt + iuslag(nc,nb,ijnbp)

    endif

  enddo
enddo

!-->TEST DE CONTROLE (NE PAS MODIFIER)

if ( (nbpart+nbpnew).ne.npt ) then
  write(nfecra,3010) nbpnew, npt-nbpart
  call csexit (1)
  !==========
endif


!===============================================================================
! 5. MODIFICATION DES POIDS POUR AVOIR LE DEBIT
!===============================================================================

!   reinitialisation du compteur de nouvelles particules

  npt = nbpart

!     pour chaque zone de bord :

  do ii = 1,nfrlag
    nb = ilflag(ii)

!         pour chaque classe :

  do nc = 1,iusncl(nb)

!         si de nouvelles particules sont entrees,
!         et si on a un debit non nul :

    if ( mod(ntcabs,iuslag(nc,nb,ijfre)).eq.0 .and.               &
         ruslag(nc,nb,idebt) .gt. 0.d0        .and.               &
         iuslag(nc,nb,ijnbp) .gt. 0                 ) then

      dmasse = 0.d0
      do ip = npt+1 , npt+iuslag(nc,nb,ijnbp)
        dmasse = dmasse + ettp(ip,jmp)
      enddo

!        Calcul des Poids

      if ( dmasse.gt.0.d0 ) then
        do ip = npt+1 , npt+iuslag(nc,nb,ijnbp)
          tepa(ip,jrpoi) = ( ruslag(nc,nb,idebt)*dtp ) / dmasse
        enddo
      else
        write(nfecra,1057) nb, nc, ruslag(nc,nb,idebt),           &
                                   iuslag(nc,nb,ijnbp)
        call csexit (1)
        !==========
      endif

      endif

      npt = npt + iuslag(nc,nb,ijnbp)

    enddo

  enddo

!-->TEST DE CONTROLE (NE PAS MODIFIER)

if ( (nbpart+nbpnew).ne.npt ) then
  write(nfecra,3010) nbpnew, npt-nbpart
  call csexit (1)
  !==========
endif

!===============================================================================
! 6. CALCUL DE LA MASSE TOTALE INJECTES EN CHAQUE ZONE
!    Attention cette valeur est modifie dans USLABO pour tenir compte
!    des particules qui sortent
!    + calcul du nombres physiques de particules qui rentrent (tenant
!       compte des poids)
!===============================================================================

!   reinitialisation du compteur de nouvelles particules

npt     = nbpart
dnbpnw = 0.d0

!     pour chaque zone de bord :

do ii = 1,nfrlag
  nb = ilflag(ii)
  deblag(nb) = 0.d0

!       pour chaque classe :

  do nc = 1,iusncl(nb)

!        si de nouvelles particules sont entrees,

    if ( mod(ntcabs,iuslag(nc,nb,ijfre)).eq.0 .and.               &
         iuslag(nc,nb,ijnbp) .gt. 0                 ) then

      do ip = npt+1 , npt+iuslag(nc,nb,ijnbp)
        deblag(nb) = deblag(nb) + tepa(ip,jrpoi)*ettp(ip,jmp)
        dnbpnw = dnbpnw + tepa(ip,jrpoi)
      enddo

    endif

    npt = npt + iuslag(nc,nb,ijnbp)

  enddo

enddo

!===============================================================================
! 7. SIMULATION DES VITESSES TURBULENTES FLUIDES INSTANTANNEES VUES
!    PAR LES PARTICULES SOLIDES LE LONG DE LEUR TRAJECTOIRE.
!===============================================================================

!   si de nouvelles particules doivent entrer :

npar1 = nbpart+1
npar2 = nbpart+nbpnew

call lagipn                                                       &
!==========
  ( ifinia , ifinra ,                                             &
    ncelet , ncel   ,                                             &
    nbpmax , nvp    , nvp1   , nvep   , nivep  ,                  &
    npar1  , npar2  ,                                             &
    nideve , nrdeve , nituse , nrtuse ,                           &
    itepa  ,                                                      &
    idevel , ituser , ia     ,                                    &
    rtpa   ,                                                      &
    ettp   , tepa   , vagaus ,                                    &
    w1     , w2     , w3     ,                                    &
    rdevel , rtuser , ra     )

!===============================================================================
! 8. MODIFICATION DES TABLEAUX DE DONNEES PARTICULAIRES
!===============================================================================

call uslain                                                       &
!==========
 ( ifinia , ifinra ,                                              &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nbpmax , nvp    , nvp1   , nvep   , nivep  ,                   &
   ntersl , nvlsta , nvisbr ,                                     &
   nbpnew ,                                                       &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml ,                   &
   ipnfac , nodfac , ipnfbr , nodfbr ,                            &
   itypfb , itrifb , itepa  , ifrlag , ia(iiwork) ,               &
   idevel , ituser , ia     ,                                     &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtpa   , propce , propfa , propfb ,                   &
   coefa  , coefb  ,                                              &
   ettp   , tepa   , vagaus , w1     , w2     , w3     ,          &
   rdevel , rtuser , ra     )

!   reinitialisation du compteur de nouvelles particules
npt = nbpart

!     pour chaque zone de bord:
do ii = 1,nfrlag
  nb = ilflag(ii)

!       pour chaque classe :
  do nc = 1, iusncl(nb)

!         si de nouvelles particules doivent entrer :
    if (mod(ntcabs,iuslag(nc,nb,ijfre)).eq.0) then

      do ip = npt+1 , npt+iuslag(nc,nb,ijnbp)

        if (ettp(ip,jdp).lt.0.d0 .and.                            &
            ruslag(nc,nb,ivdpt).gt.0.d0) then
          write(nfecra,4000) ruslag(nc,nb,idpt),                  &
                             ruslag(nc,nb,ivdpt),                 &
                             ettp(ip,jdp)
        endif

      enddo

      npt = npt + iuslag(nc,nb,ijnbp)

    endif

  enddo
enddo

!     Ici on peut laisser choir IIWORK (et donc reprendre
!       IDEBIA et IDEBRA comme indicateur de la zone de memoire libre)

!===============================================================================
! 8. IMPRESSIONS POUR POST-PROCESSING EN MODE TRAJECTOIRES
!===============================================================================

if ( iensi1.eq.1 ) then

  nfin = 0

!   reinitialisation du compteur de nouvelles particules
  npt = nbpart

!       pour chaque zone de bord :
  do ii = 1, nfrlag
    nb = ilflag(ii)

!         pour chaque classe :
    do nc = 1, iusncl(nb)

!           si de nouvelles particules doivent entrer :
      if (mod(ntcabs,iuslag(nc,nb,ijfre)).eq.0) then

        do ip = npt+1 , npt+iuslag(nc,nb,ijnbp)
          call enslag                                             &
          !==========
           ( ifinia , ifinra ,                                    &
             nbpmax , nvp    , nvp1   , nvep   , nivep  ,         &
             nfin   , ip     ,                                    &
             itepa  ,                                             &
             ettp   , tepa   , ra)
        enddo
        npt = npt + iuslag(nc,nb,ijnbp)

      endif
    enddo
  enddo
endif

!===============================================================================
! 9. NOUVEAU NOMBRE DE PARTICULES TOTAL
!===============================================================================

!     NBPART : NOMBRE DE PARTICULES PRESENTES DANS LE DOMAINE

!     NBPTOT : NOMBRE DE PARTICULES TOTAL INJECTE DANS
!              LE CALCUL DEPUIS LE DEBUT SUITE COMPRISE

nbpart = nbpart + nbpnew
dnbpar = dnbpar + dnbpnw

nbptot = nbptot + nbpnew

!===============================================================================

!--------
! FORMATS
!--------


 1000 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT INCOMPLETES OU ERRONEES ',/,&
'@                                                            ',/,&
'@  Le numero de zone associee a la face ',I10   ,' doit etre ',/,&
'@    un entier strictement positif et inferieur ou egal a    ',/,&
'@    NFLAGM = ',I10                                           ,/,&
'@  Ce numero (IFRLAG(IFAC)) vaut ici ',I10                    ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1001 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    PROBLEME DANS LES CONDITIONS AUX LIMITES                ',/,&
'@                                                            ',/,&
'@  Le nombre maximal de zones frontieres qui peuvent etre    ',/,&
'@    definies par l''utilisateur est NFLAGM = ',I10           ,/,&
'@    Il a ete depasse.                                       ',/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@  Les zones frontieres NFLAGM premieres zones frontieres    ',/,&
'@    portent ici les numeros suivants :                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1010 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT INCOMPLETES OU ERRONEES ',/,&
'@                                                            ',/,&
'@  Le nombre de classes de la zone numero ',I10   ,' doit    ',/,&
'@    etre un entier positif ou nul et inferieur ou egal      ',/,&
'@    a NCLAGM = ',I10                                         ,/,&
'@  Ce nombre (IUSNCL(NB)  ) vaut ici ',I10                    ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1020 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Le nombre de particules dans la classe         ',I10       ,/,&
'@                          dans la zone frontiere ',I10       ,/,&
'@  doit etre un entier strictement positif et                ',/,&
'@                      inferieur ou egal a NBPMAX = ',I10     ,/,&
'@                                                            ',/,&
'@  Ce nombre (IUSLAG(NC,NB,IJNBP)) vaut ici ',I10             ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1021 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : PROBLEME A L''EXECUTION DU MODULE LAGRANGIEN',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Le numero de groupe statistique de particules             ',/,&
'@     dans la classe         NC= ',I10                        ,/,&
'@     dans la zone frontiere NB= ',I10                        ,/,&
'@  doit etre un entier strictement positif et                ',/,&
'@                      inferieur ou egal a NBCLST = ',I10     ,/,&
'@                                                            ',/,&
'@  Ce nombre (IUSLAG(NC,NB,IJNBP)) vaut ici ',I10             ,/,&
'@                                                            ',/,&
'@  Le calcul continue mais cette classe statistique sera     ',/,&
'@  ignoree                                                   ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1030 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  La frequence d''injection des particules doit etre un     ',/,&
'@    entier positif ou nul (nul signifiant que               ',/,&
'@    les particules ne injectees qu''au debut du calcul).    ',/,&
'@                                                            ',/,&
'@  Ce nombre pour la frontiere NB  =',I10                     ,/,&
'@    et      pour la classe    NC  =',I10                     ,/,&
'@    vaut ici IUSLAG (NC,NB,IJFRE) =',I10                     ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1040 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Les conditions aux bords sont representees par            ',/,&
'@    une variable dont les valeurs sont                      ',/,&
'@    obligatoirement les suivantes :                         ',/,&
'@                                                            ',/,&
'@   = IENTRL  zone d''injection de particules                ',/,&
'@   = ISORTL  sortie du domaine                              ',/,&
'@   = IREBOL  rebond des particules                          ',/,&
'@   = IDEPO1  deposition definitive                          ',/,&
'@   = IDEPO2  deposition definitive mais la particule reste  ',/,&
'@             en memoire (utile si IENSI2 = 1 uniquement)    ',/,&
'@   = IDEPO3  deposition et remise en suspension possible    ',/,&
'@             suivant les condition de l''ecoulement         ',/,&
'@   = IENCRL  encrassement (Charbon uniquement IPHYLA = 2)   ',/,&
'@   = JBORD1  interaction particule/frontiere utilisateur    ',/,&
'@   = JBORD2  interaction particule/frontiere utilisateur    ',/,&
'@   = JBORD3  interaction particule/frontiere utilisateur    ',/,&
'@   = JBORD4  interaction particule/frontiere utilisateur    ',/,&
'@   = JBORD5  interaction particule/frontiere utilisateur    ',/,&
'@                                                            ',/,&
'@  Cette valeur pour la frontiere NB = ',I10                  ,/,&
'@     est erronees.                                          ',/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1041 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  La condition a la limite representee par la variable      ',/,&
'@    IDEPO2 n''est admissible que pour un post-processing    ',/,&
'@    en mode deplacement IENSI2 = 1 .                        ',/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier la valeur de IENSI2 dans USLAG1 et les           ',/,&
'@  conditions aux limites pour la frontiere NB =',I10         ,/,&
'@  dans USLAG2.                                              ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1042 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  La condition a la limite representee par le type          ',/,&
'@    IENCRL n''est admissible que lorsque les particules     ',/,&
'@    transportees sont des grains de charbon IPHYLA = 2      ',/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier la valeur de IPHYLA dans USLAG1 et les           ',/,&
'@  conditions aux limites pour la frontiere NB =',I10         ,/,&
'@  dans USLAG2.                                              ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1043 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  La condition a la limite representee par le type          ',/,&
'@    ENCRAS n''est admissible que lorsque l''option          ',/,&
'@    encrassement est enclenche IENCRA = 1                   ',/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier la valeur de IENCRA dans USLAG1 et les           ',/,&
'@  conditions aux limites pour la frontiere NB =',I10         ,/,&
'@  dans USLAG2.                                              ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1050 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Le type de condition au bord pour la vitesse est          ',/,&
'@    represente par un entier dont les valeurs sont          ',/,&
'@    obligatoirement les suivantes                           ',/,&
'@   =-1 vitesse fluide imposee                               ',/,&
'@   = 0 vitesse imposee selon la direction normale a la      ',/,&
'@       face de bord et de norme RUSLAG(NB,NC,IUNO)          ',/,&
'@   = 1 vitesse imposee : on donne RUSLAG(NB,NC,IUPT)        ',/,&
'@                                  RUSLAG(NB,NC,IVPT)        ',/,&
'@                                  RUSLAG(NB,NC,IWPT)        ',/,&
'@   = 2 profil de vitesse imposee dans USLAPR                ',/,&
'@                                                            ',/,&
'@  Ce nombre pour la frontiere NB = ',I10                     ,/,&
'@    et      pour la classe    NC = ',I10                     ,/,&
'@    vaut ici IUSLAG(NC,NB,IJUVW) = ',I10                     ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@  (Si IUSLAG(NC,NB,IJUVW) vaut -2 il n''a par ete renseigne)',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1051 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Le type de condition au bord pour le diametre est         ',/,&
'@    represente par un entier dont les valeurs sont          ',/,&
'@    obligatoirement les suivantes                           ',/,&
'@   = 1 diametre imposee dans la zone :                      ',/,&
'@                  on donne        RUSLAG(NB,NC,IDPT)        ',/,&
'@                                  RUSLAG(NB,NC,IVDPT)       ',/,&
'@   = 2 profil de diametre imposee dans USLAPR               ',/,&
'@                                                            ',/,&
'@  Ce nombre pour la frontiere  NB = ',I10                    ,/,&
'@    et      pour la classe     NC = ',I10                    ,/,&
'@    vaut ici IUSLAG(NC,NB,IJPRDP) = ',I10                    ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@ (Si IUSLAG(NC,NB,IJPRDP) vaut -2 il n''a par ete renseigne)',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1052 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Le type de condition au bord pour la temperature est      ',/,&
'@    represente par un entier dont les valeurs sont          ',/,&
'@    obligatoirement les suivantes                           ',/,&
'@   = 1 temperature imposee dans la zone :                   ',/,&
'@                  on donne        RUSLAG(NB,NC,ITPT))       ',/,&
'@   = 2 profil de temperature imposee dans USLAPR            ',/,&
'@                                                            ',/,&
'@  Ce nombre pour la frontiere  NB = ',I10                    ,/,&
'@    et      pour la classe     NC = ',I10                    ,/,&
'@    vaut ici IUSLAG(NC,NB,IJPRTP) = ',I10                    ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@ (Si IUSLAG(NC,NB,IJPRTP) vaut -2 il n''a par ete renseigne)',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1053 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Le type de condition au bord pour la taux de presence est ',/,&
'@    represente par un entier dont les valeurs sont          ',/,&
'@    obligatoirement les suivantes                           ',/,&
'@   = 1 distribution uniforme                                ',/,&
'@                  on donne        RUSLAG(NB,NC,IPOID))      ',/,&
'@   = 2 profil de taux de presence imposee dans USLAPR       ',/,&
'@                                                            ',/,&
'@  Ce nombre pour la frontiere  NB = ',I10                    ,/,&
'@    et      pour la classe     NC = ',I10                    ,/,&
'@    vaut ici IUSLAG(NC,NB,IJPRPD) = ',I10                    ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@ (Si IUSLAG(NC,NB,IJPRPD) vaut -2 il n''a par ete renseigne)',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1055 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Le poids statistique des particules doit etre un reel     ',/,&
'@    strictement positif.                                    ',/,&
'@                                                            ',/,&
'@  Ce nombre pour la frontiere NB  =',I10                     ,/,&
'@    et      pour la classe    NC  =',I10                     ,/,&
'@    vaut ici RUSLAG (NC,NB,IPOIT) =',E14.5                   ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1056 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Le debit massique des particules doit etre un reel        ',/,&
'@    positif ou nul (nul signifiant que le debit n''est pas  ',/,&
'@    pris en compte).                                        ',/,&
'@                                                            ',/,&
'@  Ce nombre pour la frontiere NB  =',I10                     ,/,&
'@    et      pour la classe    NC  =',I10                     ,/,&
'@    vaut ici RUSLAG (NC,NB,IDEBT) =',E14.5                   ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1057 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Les proprietes physiques des particules au bord pour      ',/,&
'@    la frontiere NB = ',I10   ,' et la classe NC = ',I10     ,/,&
'@    ne sont pas physiques.                                  ',/,&
'@  Le debit massique impose                                  ',/,&
'@    vaut ici RUSLAG (NC,NB,IDEBT) =',E14.5                   ,/,&
'@  alors que le nombre de particules injectees est nul       ',/,&
'@             IUSLAG (NC,NB,IJNBP) =',I10                     ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1060 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Les proprietes physiques des particules au bord pour      ',/,&
'@    la frontiere NB = ',I10   ,' et la classe NC = ',I10     ,/,&
'@    ne sont pas physiques :                                 ',/,&
'@    Masse volumique : RUSLAG(NC,NB,IROPT) = ',E14.5          ,/,&
'@    Diametre moyen  : RUSLAG(NC,NB,IDPT)  = ',E14.5          ,/,&
'@    Ecart type      : RUSLAG(NC,NB,IVDPT) = ',E14.5          ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@  Verifier le fichier dp_FCP si l''option Charbon pulverise ',/,&
'@    est activee.                                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1065 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  L''ecart-type fourni est trop grand par rapport           ',/,&
'@    au diametre moyen pour                                  ',/,&
'@    la frontiere NB = ',I10   ,' et la classe NC = ',I10     ,/,&
'@                                                            ',/,&
'@  Il y a un risque non nul de calcul d''un diametre negatif.',/,&
'@                                                            ',/,&
'@  Theoriquement 99,7% des particules se trouvent entre :    ',/,&
'@    RUSLAG(NC,NB,IDPT)-3*RUSLAG(NC,NB,IVDPT)                ',/,&
'@    RUSLAG(NC,NB,IDPT)+3*RUSLAG(NC,NB,IVDPT)                ',/,&
'@  Pour eviter des diametres aberrants, dans le module       ',/,&
'@    lagrangien, avec un clipping, on impose que 100% des    ',/,&
'@    particules doivent etre dans cet intervalle.            ',/,&
'@                                                            ',/,&
'@  Or on a :                                                 ',/,&
'@    RUSLAG(NC,NB,IDPT)-3*RUSLAG(NC,NB,IVDPT) = ',E14.5       ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@  Verifier le fichier dp_FCP si l''option Charbon pulverise ',/,&
'@    est activee.                                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1070 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Une equation sur la temperature est associee              ',/,&
'@    aux particules (IPHYLA = ',I10,') :                     ',/,&
'@    ITPVAR = ',I10                                           ,/,&
'@  Les proprietes physiques des particules au bord pour      ',/,&
'@    la frontiere NB = ',I10   ,' et la classe NC = ',I10     ,/,&
'@    doivent etre renseignees :                              ',/,&
'@    Temperature  : RUSLAG(NC,NB,ITPT) = ',E14.5              ,/,&
'@    Cp           : RUSLAG(NC,NB,ICPT) = ',E14.5              ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1075 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Une equation sur la temperature est associee              ',/,&
'@    aux particules (IPHYLA = ',I10,') :                     ',/,&
'@    ITPVAR = ',I10                                           ,/,&
'@    avec prise em compte des echanges thermiques radiatifs. ',/,&
'@  L''emissivite des particules doit etre renseignee et      ',/,&
'@    comprise entre 0 et 1 (inclus).                         ',/,&
'@                                                            ',/,&
'@  L''emissivite pour la frontiere NB = ',I10                 ,/,&
'@                     et la classe NC = ',I10                 ,/,&
'@    vaut : RUSLAG(NC,NB,IEPSI) = ',E14.5                     ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1080 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : MODULE LAGRANGIEN OPTION CHARBON PULVERISE  ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@    L''INDICATEUR SUR LE NUMERO DU CHARBON                  ',/,&
'@       A UNE VALEUR NON PERMISE (LAGOPT).                   ',/,&
'@                                                            ',/,&
'@  Le numero du charbon injecte pour                         ',/,&
'@    la frontiere NB = ',I10   ,' et la classe NC = ',I10     ,/,&
'@    devrait etre compris entre 1 et NCHARB= ',I10            ,/,&
'@    Le nombre de charbon NCHARB est donne dans dp_FCP.      ',/,&
'@                                                            ',/,&
'@    Il vaut ici  : IUSLAG(NC,NB,INUCHL) = ',I10              ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2 et le fichier dp_FCP.                     ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 1090 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : MODULE LAGRANGIEN OPTION CHARBON PULVERISE  ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  L''option de transport de particules de charbon pulverise ',/,&
'@    est active (IPHYLA = ',I10,')                           ',/,&
'@  Les proprietes physiques des particules au bord pour      ',/,&
'@    la frontiere NB = ',I10   ,' et la classe NC = ',I10     ,/,&
'@    doivent etre renseignees :                              ',/,&
'@    Temperature   : RUSLAG(NC,NB,IHPT)  = ',E14.5            ,/,&
'@    Cp            : RUSLAG(NC,NB,ICPT)  = ',E14.5            ,/,&
'@    Masse de charbon                                        ',/,&
'@    reactif       : RUSLAG(NC,NB,IMCHT) = ',E14.5            ,/,&
'@    Masse de coke : RUSLAG(NC,NB,IMCKT) = ',E14.5            ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier USLAG2 et le fichier dp_FCP.                     ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 3000 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : MODULE LAGRANGIEN                           ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Le nombre de nouvelles particules injectees conduit a un  ',/,&
'@    nombre total de particules superieur au maximum prevu : ',/,&
'@                                                            ',/,&
'@    Nombre de particules courant   : NBPART = ',I10          ,/,&
'@    Nombre de nouvelles particules : NBPNEW = ',I10          ,/,&
'@    Nombre maximal de particules   : NBPMAX = ',I10          ,/,&
'@                                                            ',/,&
'@  Le calcul se poursuit, mais on n''injecte aucune particule',/,&
'@                                                            ',/,&
'@  Ajuster NBPMAX dans USLAG1 et verifier USLAG2.            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 3010 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Le nombre de particules injectees dans le domaine         ',/,&
'@    pour cette iteration Lagrangienne ne correspond pas     ',/,&
'@    a celui specifie dans les conditions aux limites.       ',/,&
'@                                                            ',/,&
'@  Nombre de particules specifie pour l''injection :         ',/,&
'@    NBPNEW = ',I10                                           ,/,&
'@  Nombre de particules effectivement injectees :            ',/,&
'@    NPT-NBPART = ',I10                                       ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Contacter l''equipe de developpement.                     ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

 4000 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION DU MODULE LAGRANGIEN   ',/,&
'@    =========   (LAGENT)                                    ',/,&
'@                                                            ',/,&
'@    LES CONDITIONS AUX LIMITES SONT ERRONEES                ',/,&
'@                                                            ',/,&
'@  Le reconstruction du duametre d''une particule a partir   ',/,&
'@    du diametre moyen et de l''ecart type donne une valeur  ',/,&
'@    de diametre negatif, a cause d''un tirage aleatoire     ',/,&
'@    dans un des "bord de la Gaussienne".                    ',/,&
'@                                                            ',/,&
'@  Diametre moyen : ',E14.5                                   ,/,&
'@  Ecart type : ',E14.5                                       ,/,&
'@  Diametre calcule : ',E14.5                                 ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Mettre en place une verification du diametre en fonction  ',/,&
'@  des donnees granulometriques dans USLAIN.                 ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

!----
! FIN
!----

return

end subroutine
