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

subroutine elphyv &
!================

 ( idbia0 , idbra0 ,                                              &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nideve , nrdeve , nituse , nrtuse , nphmx  ,                   &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml ,                   &
   ipnfac , nodfac , ipnfbr , nodfbr , ibrom  , izfppp ,          &
   idevel , ituser , ia     ,                                     &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtp    , rtpa   , propce , propfa , propfb ,          &
   coefa  , coefb  ,                                              &
   w1     , w2     , w3     , w4     ,                            &
   w5     , w6     , w7     , w8     ,                            &
   rdevel , rtuser , ra     )

!===============================================================================
! FONCTION :
! --------

!   REMPLISSAGE DES VARIABLES PHYSIQUES : Version Electrique

!     ----> Effet Joule
!     ----> Arc Electrique
!     ----> Conduction Ionique

!      1) Masse Volumique
!      2) Viscosite moleculaire
!      3) Cp
!      4) Lambda/Cp moleculaire
!      4) Diffusivite moleculaire



! ATTENTION :
! =========


! Il est INTERDIT de modifier la viscosite turbulente VISCT ici
!        ========
!  (une routine specifique est dediee a cela : usvist)


!  Il FAUT AVOIR PRECISE ICP(IPHAS) = 1
!     ==================
!    dans usini1 si on souhaite imposer une chaleur specifique
!    CP variable pour la phase IPHAS (sinon: ecrasement memoire).


!  Il FAUT AVOIR PRECISE IVISLS(Numero de scalaire) = 1
!     ==================
!     dans usini1 si on souhaite une diffusivite VISCLS variable
!     pour le scalaire considere (sinon: ecrasement memoire).




! Remarques :
! ---------

! Cette routine est appelee au debut de chaque pas de temps

!    Ainsi, AU PREMIER PAS DE TEMPS (calcul non suite), les seules
!    grandeurs initialisees avant appel sont celles donnees
!      - dans usini1 :
!             . la masse volumique (initialisee a RO0(IPHAS))
!             . la viscosite       (initialisee a VISCL0(IPHAS))
!      - dans usiniv :
!             . les variables de calcul  (initialisees a 0 par defaut
!             ou a la valeur donnee dans usiniv)

! On peut donner ici les lois de variation aux cellules
!     - de la masse volumique                      ROM    kg/m3
!         (et eventuellememt aux faces de bord     ROMB   kg/m3)
!     - de la viscosite moleculaire                VISCL  kg/(m s)
!     - de la chaleur specifique associee          CP     J/(kg degres)
!     - des "diffusivites" associees aux scalaires VISCLS kg/(m s)


! On dispose des types de faces de bord au pas de temps
!   precedent (sauf au premier pas de temps, ou les tableaux
!   ITYPFB et ITRIFB n'ont pas ete renseignes)




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
! nphmx            ! e  ! <-- ! nphsmx                                         !
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
! ipnfac           ! te ! <-- ! position du premier noeud de chaque            !
!   (lndfac)       !    !     !  face interne dans nodfac (optionnel)          !
! nodfac           ! te ! <-- ! connectivite faces internes/noeuds             !
!   (nfac+1)       !    !     !  (optionnel)                                   !
! ipnfbr           ! te ! <-- ! position du premier noeud de chaque            !
!   (lndfbr)       !    !     !  face de bord dans nodfbr (optionnel)          !
! nodfbr           ! te ! <-- ! connectivite faces de bord/noeuds              !
!   (nfabor+1)     !    !     !  (optionnel)                                   !
! ibrom            ! te ! <-- ! indicateur de remplissage de romb              !
!   (nphmx   )     !    !     !                                                !
! izfppp           ! te ! <-- ! numero de zone de la face de bord              !
! (nfabor)         !    !     !  pour le module phys. part.                    !
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
! dt(ncelet)       ! tr ! <-- ! pas de temps                                   !
! rtp, rtpa        ! tr ! <-- ! variables de calcul au centre des              !
! (ncelet,*)       !    !     !    cellules (instant courant ou prec)          !
! propce           ! tr ! <-- ! proprietes physiques au centre des             !
! (ncelet,*)       !    !     !    cellules                                    !
! propfa           ! tr ! <-- ! proprietes physiques au centre des             !
!  (nfac,*)        !    !     !    faces internes                              !
! propfb           ! tr ! <-- ! proprietes physiques au centre des             !
!  (nfabor,*)      !    !     !    faces de bord                               !
! coefa, coefb     ! tr ! <-- ! conditions aux limites aux                     !
!  (nfabor,*)      !    !     !    faces de bord                               !
! w1...8(ncelet    ! tr ! --- ! tableau de travail                             !
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
include "numvar.h"
include "optcal.h"
include "cstnum.h"
include "cstphy.h"
include "entsor.h"
include "ppppar.h"
include "ppthch.h"
include "ppincl.h"
include "elincl.h"

!===============================================================================

! Arguments

integer          idbia0 , idbra0
integer          ndim   , ncelet , ncel   , nfac   , nfabor
integer          nfml   , nprfml
integer          nnod   , lndfac , lndfbr , ncelbr
integer          nvar   , nscal  , nphas
integer          nideve , nrdeve , nituse , nrtuse , nphmx

integer          ifacel(2,nfac) , ifabor(nfabor)
integer          ifmfbr(nfabor) , ifmcel(ncelet)
integer          iprfml(nfml,nprfml)
integer          ipnfac(nfac+1), nodfac(lndfac)
integer          ipnfbr(nfabor+1), nodfbr(lndfbr), ibrom(nphmx)
integer          izfppp(nfabor)
integer          idevel(nideve), ituser(nituse), ia(*)

double precision xyzcen(ndim,ncelet)
double precision surfac(ndim,nfac), surfbo(ndim,nfabor)
double precision cdgfac(ndim,nfac), cdgfbo(ndim,nfabor)
double precision xyznod(ndim,nnod), volume(ncelet)
double precision dt(ncelet), rtp(ncelet,*), rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfa(nfac,*), propfb(nfabor,*)
double precision coefa(nfabor,*), coefb(nfabor,*)
double precision w1(ncelet),w2(ncelet),w3(ncelet),w4(ncelet)
double precision w5(ncelet),w6(ncelet),w7(ncelet),w8(ncelet)
double precision rdevel(nrdeve), rtuser(nrtuse), ra(*)

! VARIABLES LOCALES

integer          idebia, idebra, ifinia
integer          iel   , iphas
integer          ipcrom, ipcvis, ipccp , ipcray
integer          ipcvsl, ith   , iscal , ii
integer          iiii  , ipcsig, it
integer          iesp  , iesp1 , iesp2 , mode , isrrom
integer          maxelt, ils

double precision tp    , delt  , somphi, val
double precision alpro , alpvis, alpcp , alpsig, alplab , alpkab
double precision rhonp1
double precision ym    (ngazgm),yvol  (ngazgm)
double precision coef(ngazgm,ngazgm)
double precision roesp (ngazgm),visesp(ngazgm),cpesp(ngazgm)
double precision sigesp(ngazgm),xlabes(ngazgm),xkabes(ngazgm)

integer          ipass
data             ipass /0/
save             ipass

!===============================================================================
!===============================================================================
! 0 - INITIALISATIONS A CONSERVER
!===============================================================================

! --- Initialisation memoire

idebia = idbia0
idebra = idbra0

ipass = ipass + 1

iphas = 1

!     Sous relaxation de la masse volumique (pas au premier pas de temps)
if(ntcabs.gt.1.and.srrom.gt.0.d0) then
  isrrom = 1
else
  isrrom = 0
endif

!===============================================================================
! 1 - EFFET JOULE
!===============================================================================

!  -- Les lois doivent etre imposees par l'utilisateur
!       donc on ne fait rien.

!      IF ( IPPMOD(IELJOU).GE.1 ) THEN


!  -- Attention, dans les modules electriques, la chaleur massique, la
!       conductivite thermique et la conductivite electriques sont
!       toujours dans le tableau PROPCE
!       qu'elles soient physiquement variables ou non.

!       On n'utilisera donc PAS les variables
!          =====================
!                                CP0(IPHAS), VISLS0(ISCALT(IPHAS))
!                                VISLS0(IPOTR) et VISLS0(IPOTI)

!       Informatiquement, ceci se traduit par le fait que
!                                ICP(IPHAS)>0, IVISLS(ISCALT(IPHAS))>0,
!                                IVISLS(IPOTR)>0 et IVISLS(IPOTI)>0

!       Les verifications ont ete faites dans elveri

!  -- Si la conductivite electrique est toujours la meme pour
!       le potentiel reel et le potentiel imaginaire, on pourrait
!       n'en avoir qu'une seule (modif dans varpos pour definir
!       IVISLS(IPOTI) = IVISLS(IPOTR)) et economiser NCEL reels .

!      IPCROM = IPPROC(IROM(IPHAS))
!      IPCVIS = IPPROC(IVISCL(IPHAS))
!      IPCCP  = IPPROC(ICP(IPHAS))
!      IPCVSL = IPPROC(IVISLS(ISCALT(IPHAS)))
!      IPCSIR = IPPROC(IVISLS(IPOTR))
!      IPCSII = IPPROC(IVISLS(IPOTI))

!      PROPCE(IEL,IPPROC(ITEMP)) =
!      PROPCE(IEL,IPCROM) =
!      PROPCE(IEL,IPCVIS) =
!      PROPCE(IEL,IPCCP) =
!      PROPCE(IEL,IPCVSL) =
!      PROPCE(IEL,IPCSIR) =
!      PROPCE(IEL,IPCSII) =

!      ENDIF

!===============================================================================
! 2 - ARC ELECTRIQUE
!===============================================================================

if ( ippmod(ielarc).ge.1 ) then

!      Un message une fois au moins pour dire
!                                    qu'on prend les valeurs sur fichier
  if(ipass.eq.1) then
    write(nfecra,1000)
  endif

!      Calcul de la temperature a partir de l'enthalpie

  mode = 1

  if ( ngazg .eq. 1 ) then
    ym(1) = 1.d0
    mode = 1
    do iel = 1, ncel
      call elthht(mode,ngazg,ym,rtp(iel,isca(ihm)),               &
                                propce(iel,ipproc(itemp)))
    enddo
  else
    do iel = 1, ncel
      ym(ngazg) = 1.d0
      do iesp = 1, ngazg-1
        ym(iesp) = rtp(iel,isca(iycoel(iesp)))
        ym(ngazg) = ym(ngazg) - ym(iesp)
      enddo
      call elthht(mode,ngazg,ym,rtp(iel,isca(ihm)),               &
                                propce(iel,ipproc(itemp)))
    enddo
  endif

!      Pointeurs pour les differentes variables

  ipcrom = ipproc(irom(iphas))
  ipcvis = ipproc(iviscl(iphas))
  if(icp(iphas).gt.0) then
    ipccp  = ipproc(icp(iphas))
  endif
  if(ivisls(iscalt(iphas)).gt.0) then
    ipcvsl = ipproc(ivisls(iscalt(iphas)))
  endif
  if ( ivisls(ipotr).gt.0 ) then
    ipcsig = ipproc(ivisls(ipotr))
  endif
  if ( ixkabe .gt. 0 ) then
     ipcray = ipproc(idrad)
  endif

!       Interpolation des donnees sur le fichier de donnees
!         en fonction de la temperature

  do iel = 1, ncel

!        Valeur de la temperature

    tp = propce(iel,ipproc(itemp))

!        On determine  le IT ou il faut interpoler

    it = 0
    if ( tp .le. th(1) ) then
      it = 1
    else if ( tp .ge. th(npo) ) then
      it = npo
    else
      do iiii = 1, npo-1
        if ( tp .gt. th(iiii) .and. tp .le. th(iiii+1) ) then
          it = iiii
        endif
      enddo
    endif
    if ( it .eq. 0 ) then
      write(nfecra,9900) tp
      call csexit(1)
    endif

!        Fraction massique

    ym(ngazg) = 1.d0
    do iesp = 1, ngazg-1
      ym(iesp)  = rtp(iel,isca(iycoel(iesp)))
      ym(ngazg) = ym(ngazg) - ym(iesp)
    enddo

!     Masse volumique, Viscosite, CP, Sigm et Lambda de chaque constituant

    if ( tp .le. th(1) ) then

!         Extrapolation : Valeur constante = 1ere valeur de la table

      do iesp = 1, ngazg
        roesp (iesp) = rhoel (iesp,1)
        visesp(iesp) = visel (iesp,1)
        cpesp (iesp) = cpel  (iesp,1)
        sigesp(iesp) = sigel (iesp,1)
        xlabes(iesp) = xlabel(iesp,1)
        if ( ixkabe .gt. 0 ) then
          xkabes(iesp) = xkabel(iesp,1)
        endif
      enddo

    else if ( tp .ge. th(npo) ) then

!         Extrapolation : valeur constante = derniere valeur de la table

      do iesp = 1, ngazg
        roesp (iesp) = rhoel (iesp,npo)
        visesp(iesp) = visel (iesp,npo)
        cpesp (iesp) = cpel  (iesp,npo)
        sigesp(iesp) = sigel (iesp,npo)
        xlabes(iesp) = xlabel(iesp,npo)
        if ( ixkabe .gt. 0 ) then
          xkabes(iesp) = xkabel(iesp,npo)
        endif
      enddo

    else

!         Interpolation

      delt = th(it+1) - th(it)
      do iesp = 1, ngazg

!          Masse volumique de chaque constituant

        alpro = (rhoel(iesp,it+1)-rhoel(iesp,it))/delt
        roesp(iesp)  = rhoel(iesp,it) + alpro*(tp-th(it))

!          Viscosite de chaque constituant

        alpvis = (visel(iesp,it+1)-visel(iesp,it))/delt
        visesp(iesp) = visel(iesp,it) + alpvis*(tp-th(it))

!          CP de chaque constituant

        alpcp = (cpel(iesp,it+1)-cpel(iesp,it))/delt
        cpesp(iesp) = cpel(iesp,it) + alpcp*(tp-th(it))

!          Conductivite electrique (Sigma) de chaque constituant

        alpsig = (sigel(iesp,it+1)-sigel(iesp,it))/delt
        sigesp(iesp) = sigel(iesp,it) + alpsig*(tp-th(it))

!          Conductivite thermique (Lambda) de chaque constituant

        alplab = (xlabel(iesp,it+1)-xlabel(iesp,it))/delt
        xlabes(iesp) = xlabel(iesp,it) + alplab*(tp-th(it))

!          Emission nette radiative ou Terme source radiatif
!          de chaque constituant

        if ( ixkabe .gt. 0 ) then
          alpkab = (xkabel(iesp,it+1)-xkabel(iesp,it))/delt
          xkabes(iesp) = xkabel(iesp,it) + alpkab*(tp-th(it))
        endif

      enddo

    endif

!       Masse volumique du melange (sous relaxee eventuellement)
!       ==========================

    rhonp1 = 0.d0
    do iesp = 1, ngazg
      rhonp1 = rhonp1+ym(iesp)/roesp(iesp)
    enddo
    rhonp1 = 1.d0/rhonp1
    if(isrrom.eq.1) then
      propce(iel,ipcrom) =                                        &
           srrom*propce(iel,ipcrom)+(1.d0-srrom)*rhonp1
    else
      propce(iel,ipcrom) = rhonp1
    endif

!        Fraction volumique de chaque constituant

    do iesp = 1, ngazg
      yvol(iesp) = ym(iesp)*roesp(iesp)/propce(iel,ipcrom)
      if ( yvol(iesp) .le. 0.d0 ) yvol(iesp) = epzero**2
    enddo

!       Viscosite moleculaire dynamique en kg/(m s)
!       ==========================================

    do iesp1 = 1, ngazg
      do iesp2 = 1, ngazg
        coef(iesp1,iesp2) = ( 1.d0                                &
               + sqrt(visesp(iesp1)/visesp(iesp2))                &
                *sqrt(sqrt(roesp(iesp2)/roesp(iesp1))))**2.       &
                / sqrt( 1.d0 + roesp(iesp1)/roesp(iesp2) )        &
            / sqrt(8.d0)
      enddo
    enddo

    propce(iel,ipcvis) = 0.d0
    do iesp1=1,ngazg

      somphi = 0.d0
      do iesp2=1,ngazg
        if ( iesp1 .ne. iesp2 ) then
          somphi = somphi                                         &
                  +coef(iesp1,iesp2)*yvol(iesp2)/yvol(iesp1)
        endif
      enddo

      propce(iel,ipcvis) = propce(iel,ipcvis)                     &
                          +visesp(iesp1)/(1.d0+somphi)

    enddo

!       Chaleur specifique J/(kg degres)
!       ================================

    if(icp(iphas).gt.0) then

      propce(iel,ipccp) = 0.d0
      do iesp = 1, ngazg
        propce(iel,ipccp) = propce(iel,ipccp )                    &
                            +ym(iesp)*cpesp(iesp)
      enddo

    endif

!       Lambda/Cp en kg/(m s)
!       ---------------------

    if(ivisls(iscalt(iphas)).gt.0) then

      do iesp1=1,ngazg
        do iesp2=1,ngazg
          coef(iesp1,iesp2) = ( 1.d0                              &
                 + sqrt(xlabes(iesp1)/xlabes(iesp2))              &
                  *sqrt(sqrt(roesp(iesp2)/roesp(iesp1))))**2.d0   &
                  / sqrt( 1.d0 + roesp(iesp1)/roesp(iesp2) )      &
              / sqrt(8.d0)
        enddo
      enddo

!        On calcule d'abord juste Lambda

      propce(iel,ipcvsl) = 0.d0
      do iesp1=1,ngazg

        somphi = 0.d0
        do iesp2=1,ngazg
          if ( iesp1 .ne. iesp2 ) then
            somphi = somphi                                       &
                    +coef(iesp1,iesp2)*yvol(iesp2)/yvol(iesp1)
          endif
        enddo

        propce(iel,ipcvsl) = propce(iel,ipcvsl)                   &
                            +xlabes(iesp1)/(1.d0+1.065*somphi)

      enddo

!        On divise par CP pour avoir Lambda/CP
!          On suppose Cp renseigne au prealable.

      if(ipccp.le.0) then

! --- Si CP est uniforme, on utilise CP0(IPHAS)

        propce(iel,ipcvsl) = propce(iel,ipcvsl)/cp0(iphas)

      else

! --- Si CP est non uniforme, on utilise le CP calcul au dessus
        propce(iel,ipcvsl) = propce(iel,ipcvsl)/propce(iel,ipccp)

      endif
    endif

!       Conductivite electrique en S/m
!       ==============================

    if ( ivisls(ipotr).gt.0 ) then
      propce(iel,ipcsig) = 0.d0
      val = 0.d0
      do iesp=1,ngazg
        val = val + yvol(iesp)/sigesp(iesp)
      enddo

      propce(iel,ipcsig) = 1.d0/val
    endif

!       Emission nette radiative en W/m3
!       ================================

    if ( ixkabe .gt. 0 ) then
      propce(iel,ipcray) = 0.d0
      val = 0.d0
      do iesp=1,ngazg
        val = val + yvol(iesp)*xkabes(iesp)
      enddo

      propce(iel,ipcray) = val
    endif

  enddo

!       Diffusivite variable a l'exclusion de l'enthalpie et de IPOTR
!       -------------------------------------------------------------
!         Il n'y a pas d'autres scalaires, et la boucle ne fait donc rien


  do ii = 1, nscapp

! --- Numero du scalaire
    iscal = iscapp(ii)

! --- Si il s'agit de l'enthalpie son cas a deja ete traite plus haut
    ith = 0
    if (iscal.eq.iscalt(iphas)) ith = 1

! --- Si il s'agit de Potentiel (IPOTR), son cas a deja ete traite
    if (iscal.eq.ipotr) ith = 1

! --- Si la variable est une fluctuation, sa diffusivite est
!       la meme que celle du scalaire auquel elle est rattachee :
!       il n'y a donc rien a faire ici : on passe directement
!       a la variable suivante sans renseigner PROPCE(IEL,IPCVSL).

    if ( ith.eq.0 .and. iscavr(iscal).le.0) then

! --- On ne traite ici que les variables non thermiques
!                                        et pas le potentiel (sigma)
!                                   et qui ne sont pas des fluctuations

      if(ivisls(iscal).gt.0) then

! --- Rang de Lambda du scalaire
!     dans PROPCE, prop. physiques au centre des elements       : IPCVSL

        ipcvsl = ipproc(ivisls(iscal))

        do iel = 1, ncel
          propce(iel,ipcvsl) = 1.d0
        enddo

      endif

    endif

  enddo

endif

!===============================================================================
! 3 - CONDUCTION IONIQUE
!===============================================================================

! POUR LE MOMENT CETTE OPTION N'EST PAS ACTIVEE

if ( ippmod(ielion).ge.1  ) then

!       Masse volumique
!       ---------------

  ipcrom = ipproc(irom(iphas))
  do iel = 1, ncel
    propce(iel,ipcrom) = 1.d0
  enddo

!       VISCOSITE
!       =========

  ipcvis = ipproc(iviscl(iphas))
  do iel = 1, ncel
    propce(iel,ipcvis) = 1.d-2
  enddo

!       CHALEUR SPECIFIQUE VARIABLE J/(kg degres)
!       =========================================

  if(icp(iphas).gt.0) then

    ipccp  = ipproc(icp   (iphas))

    do iel = 1, ncel
      propce(iel,ipccp ) = 1000.d0
    enddo

  endif

!       Lambda/CP  VARIABLE en kg/(m s)
!       ===============================

  if (ivisls(iscalt(iphas)).gt.0) then

    ipcvsl = ipproc(ivisls(iscalt(iphas)))

    if(ipccp.le.0) then

! --- Si CP est uniforme, on utilise CP0(IPHAS)

      do iel = 1, ncel
        propce(iel,ipcvsl) = 1.d0/cp0(iphas)
      enddo

    else

! --- Si CP est non uniforme, on utilise PROPCE ci dessus
      do iel = 1, ncel
        propce(iel,ipcvsl) = 1.d0 /propce(iel,ipccp)
      enddo

    endif

  endif

!       DIFFUSIVITE VARIABLE A L'EXCLUSION DE L'ENTHALPIE
!       ==================================================

  do ii = 1, nscapp

! --- Numero du scalaire
    iscal = iscapp(ii)

! --- Si il s'agit de l'enthqlpie son cas a deja ete traite plus haut
    ith = 0
    if (iscal.eq.iscalt(iphas)) ith = 1

! --- Si la variable est une fluctuation, sa diffusivite est
!       la meme que celle du scalaire auquel elle est rattachee :
!       il n'y a donc rien a faire ici : on passe directement
!       a la variable suivante sans renseigner PROPCE(IEL,IPCVSL).

    if ( ith.eq.0 .and. iscavr(iscal).le.0) then

! --- On ne traite ici que les variables non thermiques
!                                   et qui ne sont pas des fluctuations

      if(ivisls(iscal).gt.0) then

! --- Rang de Lambda du scalaire
!     dans PROPCE, prop. physiques au centre des elements       : IPCVSL

        ipcvsl = ipproc(ivisls(iscal))

! --- Lambda en kg/(m s) au centre des cellules


        do iel = 1, ncel
          propce(iel,ipcvsl) = 1.d0
        enddo

      endif

    endif

  enddo

endif

!===============================================================================
! 4 - ON PASSE LA MAIN A L'UTILISATEUR (joule en particulier)
!===============================================================================

maxelt = max(ncelet, nfac, nfabor)
ils    = idebia
ifinia = ils + maxelt
CALL IASIZE('ELPHYV',IFINIA)

call uselph                                                       &
!==========
 ( ifinia , idebra ,                                              &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nideve , nrdeve , nituse , nrtuse , nphmx  ,                   &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml , maxelt , ia(ils), &
   ipnfac , nodfac , ipnfbr , nodfbr , ibrom  , izfppp ,          &
   idevel , ituser , ia     ,                                     &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtp    , rtpa   , propce , propfa , propfb ,          &
   coefa  , coefb  ,                                              &
   w1     , w2     , w3     , w4     ,                            &
   w5     , w6     , w7     , w8     ,                            &
   rdevel , rtuser , ra     )



! La masse volumique au bord est traitee dans phyvar (recopie de la valeur
!     de la cellule de bord).

!--------
! FORMATS
!--------

 1000 format(/,                                                   &
' Module electrique: proprietes physiques lues sur fichier',/)
 9900 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ERREUR DANS ELPHYV (MODULE ELECTRIQUE)      ',/,&
'@    =========                                               ',/,&
'@                                                            ',/,&
'@  Tabulation echoue avec une temperature TP = ', E14.5       ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

!----
! FIN
!----

return
end subroutine
