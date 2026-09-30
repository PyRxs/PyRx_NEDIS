/**********************************************************************
  NEDIS 2022 : 경상북도 + 28대 중증응급 축소 버전 (0~5단계)
  - 흐름
      0단계  원자료 import -> 경북(환자 거주지 기준)만 추출                    -> save.PTM2022_GB
      2단계  중증외상(ICISS/SRR 2020) 산출 (경북 데이터에만 수행)              -> save.otdc_srr
      3단계  클리닝 + 28대 중증응급 정의 후 emergency_dis=1 만 추출            -> save.PTM2022_3
      4단계  지역(시도/시군구/진료권/응급의료권역), 대구 특정병원 등 주요 변수 정의 -> save.PTM2022_4
      5단계  변수 정리(drop/label) + 경북 최종 데이터셋 추출                   -> save.PTM2022_5 / save.pa_area / save.hp_area
  - 아래 분석은 save.PTM2022_5(=save.pa_area)의 변수만으로 바로 가능:
      1) 질환별 유출 현황     : emergency_dis_1~28 × gb_sigu_out/gb_sido_out/gb_6gr/gb_4gr
      2) 대구 소재 병원 유출  : daegu, daegu_top, ttop_dg, gb_dg_go, gb_dg_topgo
      3) 대구 특정 6개 병원   : gb_hp, gb_hp_yu, gb_hp_ga, gb_hp_ch, gb_hp_gae, gb_hp_pati
         (경북대·영남대·가톨릭대·칠곡경북대·계명대동산·대구파티마 외 다른 병원은
          PTMIEMNM 기준으로 별도 변수를 추가해야 함)
**********************************************************************/

libname save '\\172.30.1.200\경북지원단\경북지원단\공공보건의료 협력체계 구축사업 기초조사 위탁 용역\응급 NEDIS 임시';

/*--------------------------------------------------------------------
  0단계: import 후 경북만 추출
   - 환자 거주지(PTMIGUCD)가 47xxx인 건만 남김 (응급의료기관 소재지는 보지 않음
     -> 경북 밖 병원을 이용한 경북 거주자의 대구 유출(gb_dg_go) 등, 응급의료기관
        소재지 기준 분석이 필요해지면 이 조건에 PTMIEMAR 조건을 다시 추가할 것)
   - GUESSINGROWS=MAX : 450000행 이후에 '-' 등 문자가 나오면 숫자형으로 잘못 추정되어
     값이 결측 처리될 수 있어서 MAX 로 변경 (느리면 다시 낮추되 변수 타입 확인 필요)
--------------------------------------------------------------------*/
PROC IMPORT OUT=work.PTM2022_raw
DATAFILE="\\172.30.1.200\경북지원단\경북지원단\경상북도 응급의료지원단\NEDIS\JE20241103\JE20241103\2022.csv"
DBMS=csv REPLACE;
GETNAMES=YES;
GUESSINGROWS=MAX;
RUN;

data save.PTM2022_GB;
set work.PTM2022_raw;
length _g $20;
_g=strip(vvalue(PTMIGUCD));   /* 숫자/문자형 어느 쪽으로 읽혀도 동작 */
if substr(_g,1,2)='47';
drop _g;
run;

proc datasets lib=work nolist; delete PTM2022_raw; quit;

proc sort data=save.PTM2022_GB; by PTMIIDNO; run;


/**********************************************************
      2단계: NEDIS 중증외상 정의 (SRR 2020, ICISS<0.9)
      퇴실/퇴원 진단코드 01~20 중 주/부진단(구분 1,2)만 사용
 **********************************************************/

/* 외상 해당 코드 목록: ot / dc 에서 공통 사용 (원본과 동일) */
%let trauma_codes =
'S01', 'S010', 'S011', 'S012', 'S013', 'S014', 'S015', 'S017', 'S018', 'S019', 'S02', 'S020', 'S021', 'S022', 'S023', 'S024', 'S025', 'S026', 'S027', 'S028', 'S029',
'S030', 'S031', 'S032', 'S033', 'S034', 'S035', 'S04', 'S040', 'S041', 'S042', 'S043', 'S044', 'S045', 'S046', 'S048', 'S049', 'S05', 'S050', 'S051', 'S052', 'S053', 'S054',
'S055', 'S056', 'S057', 'S058', 'S059','S06', 'S060', 'S061', 'S062', 'S063', 'S064', 'S065', 'S066', 'S067', 'S068', 'S069', 'S07', 'S070', 'S071', 'S078', 'S079', 'S080',
'S081', 'S088', 'S089', 'S09', 'S090', 'S091', 'S092', 'S097', 'S098', 'S099', 'S11', 'S110', 'S111', 'S112', 'S117', 'S118', 'S119', 'S12', 'S120', 'S121', 'S122', 'S127',
'S128', 'S129', 'S13', 'S130', 'S131', 'S132', 'S133', 'S134', 'S135', 'S136', 'S14', 'S140', 'S141', 'S142', 'S143', 'S144', 'S145', 'S146', 'S150', 'S151', 'S152', 'S153',
'S157', 'S158', 'S159', 'S16', 'S170', 'S178', 'S179', 'S197', 'S198', 'S199', 'S21', 'S210', 'S211', 'S212', 'S217', 'S218', 'S219', 'S22', 'S220', 'S221', 'S222', 'S223',
'S224', 'S225', 'S228', 'S229', 'S23', 'S230', 'S231', 'S232', 'S233', 'S234', 'S235', 'S240', 'S241', 'S242', 'S244', 'S245', 'S246', 'S250', 'S251', 'S252', 'S253', 'S254',
'S255', 'S257', 'S258', 'S259', 'S260', 'S268', 'S269', 'S27', 'S270', 'S271', 'S272', 'S273', 'S274', 'S275', 'S276', 'S277', 'S278', 'S279', 'S280', 'S281', 'S290', 'S297',
'S298', 'S299', 'S31', 'S310', 'S311', 'S312', 'S313', 'S314', 'S315', 'S317', 'S318', 'S32', 'S320', 'S321', 'S322', 'S323', 'S324', 'S325', 'S327', 'S328', 'S33', 'S330',
'S331', 'S332', 'S333', 'S334', 'S335', 'S336', 'S337', 'S34', 'S340', 'S341', 'S342', 'S343', 'S344', 'S345', 'S346', 'S348', 'S35', 'S350', 'S351', 'S352', 'S353', 'S354',
'S355', 'S357', 'S358', 'S359', 'S36', 'S360', 'S361', 'S362', 'S363', 'S364', 'S365', 'S366', 'S367', 'S368', 'S369', 'S37', 'S370', 'S371', 'S372', 'S373', 'S374', 'S375',
'S376', 'S377', 'S378', 'S379', 'S380', 'S381', 'S382', 'S383', 'S39', 'S390', 'S396', 'S397', 'S398', 'S399', 'S41', 'S410', 'S411', 'S417', 'S418', 'S42', 'S420', 'S421',
'S422', 'S423', 'S424', 'S427', 'S428', 'S429', 'S43', 'S430', 'S431', 'S432', 'S433', 'S434', 'S435', 'S436', 'S437', 'S44', 'S440', 'S441', 'S442', 'S443', 'S444', 'S445',
'S447', 'S448', 'S449', 'S45', 'S450', 'S451', 'S452', 'S453', 'S457', 'S458', 'S459', 'S460', 'S461', 'S462', 'S463', 'S467', 'S468', 'S469', 'S47', 'S480', 'S481', 'S489',
'S497', 'S498', 'S499', 'S51', 'S510', 'S517', 'S518', 'S519', 'S52', 'S520', 'S521', 'S522', 'S523', 'S524', 'S525', 'S526', 'S527', 'S528', 'S529', 'S53', 'S530', 'S531',
'S532', 'S533', 'S534', 'S54', 'S540', 'S541', 'S542', 'S543', 'S547', 'S548', 'S549', 'S55', 'S550', 'S551', 'S552', 'S557', 'S558', 'S559', 'S56', 'S560', 'S561', 'S562',
'S563', 'S564', 'S565', 'S567', 'S568', 'S570', 'S578', 'S579', 'S580', 'S581', 'S589', 'S597', 'S598', 'S599', 'S61', 'S610', 'S611', 'S617', 'S618', 'S619', 'S62', 'S620',
'S621', 'S622', 'S623', 'S624', 'S625', 'S626', 'S627', 'S628', 'S63', 'S630', 'S631', 'S632', 'S633', 'S634', 'S635', 'S636', 'S637', 'S64', 'S640', 'S641', 'S642', 'S643',
'S644', 'S647', 'S648', 'S649', 'S65', 'S650', 'S651', 'S652', 'S653', 'S654', 'S655', 'S657', 'S658', 'S659', 'S66', 'S660', 'S661', 'S662', 'S663', 'S664', 'S665', 'S666',
'S667', 'S668', 'S669', 'S67', 'S670', 'S678', 'S68', 'S680', 'S681', 'S682', 'S683', 'S684', 'S688', 'S689', 'S697', 'S698', 'S699', 'S71', 'S710', 'S711', 'S717', 'S718',
'S72', 'S720', 'S721', 'S722', 'S723', 'S724', 'S727', 'S728', 'S729', 'S73', 'S730', 'S731', 'S74', 'S740', 'S741', 'S742', 'S747', 'S748', 'S749', 'S750', 'S751', 'S752',
'S757', 'S758', 'S759', 'S76', 'S760', 'S761', 'S762', 'S763', 'S764', 'S767', 'S770', 'S771', 'S772', 'S780', 'S781', 'S789', 'S79', 'S797', 'S798', 'S799', 'S81', 'S810',
'S817', 'S818', 'S819', 'S82', 'S820', 'S821', 'S822', 'S823', 'S824', 'S825', 'S826', 'S827', 'S828', 'S829', 'S83', 'S830', 'S831', 'S832', 'S833', 'S834', 'S835', 'S836',
'S837', 'S840', 'S841', 'S842', 'S847', 'S848', 'S849', 'S850', 'S851', 'S852', 'S853', 'S854', 'S855', 'S857', 'S858', 'S859', 'S86', 'S860', 'S861', 'S862', 'S863', 'S867',
'S868', 'S869', 'S87', 'S870', 'S878', 'S880', 'S881', 'S889', 'S897', 'S898', 'S899', 'S91', 'S910', 'S911', 'S912', 'S913', 'S917', 'S92', 'S920', 'S921', 'S922', 'S923',
'S924', 'S925', 'S927', 'S929', 'S93', 'S930', 'S931', 'S932', 'S933', 'S934', 'S935', 'S936', 'S94', 'S940', 'S941', 'S942','S943', 'S947', 'S948', 'S949', 'S95', 'S950',
'S951', 'S952', 'S957', 'S958', 'S959', 'S96', 'S960', 'S961', 'S962', 'S967', 'S968', 'S969', 'S97', 'S970', 'S971', 'S978', 'S98', 'S980', 'S981', 'S982', 'S983', 'S984',
'S99', 'S997', 'S998', 'S999', 'T010', 'T011', 'T012', 'T013', 'T016', 'T018', 'T019', 'T020', 'T021', 'T022', 'T023', 'T024', 'T025', 'T026', 'T027', 'T028', 'T029', 'T030',
'T031', 'T032', 'T033', 'T034', 'T038', 'T039', 'T040', 'T041', 'T042', 'T043', 'T044', 'T047', 'T048', 'T049', 'T050', 'T051', 'T052', 'T053', 'T054', 'T055', 'T056', 'T058',
'T059', 'T060', 'T061', 'T062', 'T063', 'T064', 'T065', 'T068', 'T07', 'T08', 'T080', 'T081', 'T09', 'T091', 'T092', 'T093', 'T094', 'T095', 'T096', 'T098', 'T099', 'T100', 'T101',
'T111', 'T112', 'T113', 'T114', 'T115', 'T116', 'T118', 'T119', 'T12', 'T120', 'T121', 'T131', 'T132', 'T133', 'T134', 'T135', 'T136', 'T138', 'T139', 'T141', 'T142', 'T143',
'T144', 'T145', 'T146', 'T147', 'T148', 'T149', 'T20', 'T200', 'T202', 'T203', 'T204', 'T206', 'T207', 'T21', 'T210', 'T212', 'T213', 'T214', 'T216', 'T22', 'T220', 'T222', 'T223',
'T224', 'T226', 'T227', 'T23', 'T230', 'T232', 'T233', 'T234', 'T236', 'T237', 'T24', 'T240', 'T242', 'T243', 'T244', 'T246', 'T247', 'T250', 'T252', 'T253', 'T254', 'T256',
'T257', 'T260', 'T261', 'T262', 'T263', 'T264', 'T265', 'T266', 'T267', 'T268', 'T269', 'T27', 'T270', 'T271', 'T272', 'T273', 'T274', 'T276', 'T277', 'T280', 'T281', 'T282', 'T283',
'T284', 'T285', 'T286', 'T287', 'T289', 'T290', 'T292', 'T293', 'T294', 'T296', 'T297', 'T300', 'T302', 'T303', 'T304', 'T310', 'T311', 'T312', 'T313', 'T314', 'T315', 'T316',
'T317', 'T318', 'T319', 'T320', 'T321', 'T322', 'T326', 'T345', 'T348', 'T349', 'T350', 'T351', 'T352', 'T354', 'T355', 'T356', 'T357', 'T79', 'T790', 'T791', 'T792', 'T794',
'T795', 'T796', 'T797', 'T798', 'T799';

/* &pre = DGOT(응급실 퇴실 후) / DGDC(퇴원 후),  &sfx = ot / dc
   원본의 a1~a20 (x2) 40개 data step + 중복 코드를 배열 1회 pass 로 대체 */
%macro iciss(pre=, sfx=);

  /* 진단코드 long 형태: 외상코드(4자리)만 남김, 환자+코드 중복 제거 */
  data work.&sfx._long(keep=PTMIIDNO diag2);
    set save.PTM2022_GB(keep=PTMIIDNO &pre.DGGB01-&pre.DGGB20 &pre.DIAG01-&pre.DIAG20);
    array gb {20} &pre.DGGB01-&pre.DGGB20;
    array dg {20} &pre.DIAG01-&pre.DIAG20;
    do i=1 to 20;
      if strip(vvalue(gb{i})) in ('1','2') then do;   /* 주/부진단 (의증 제외) */
        diag2=substr(dg{i},1,4);
        if diag2 in (&trauma_codes.) then output;
      end;
    end;
  run;

  /* [수정] 원본은 nodup by PTMIIDNO 라 비인접 중복이 남을 수 있음 -> 환자+코드 기준 중복 제거 */
  proc sort data=work.&sfx._long nodupkey; by PTMIIDNO diag2; run;

  /* SRR 매칭 (srr 값이 없는 코드는 제외) */
  proc sql;
    create table work.&sfx.srr as
    select a.PTMIIDNO, a.diag2, b.srr
    from work.&sfx._long a inner join save.srr b
    on a.diag2=b.diag2
    where b.srr is not null
    order by a.PTMIIDNO, b.srr;
  quit;

  /* 환자별 SRR 낮은 순 3개를 곱해 ICISS 산출 (원본의 rank/분할/merge 를 1 pass 로) */
  data save.&sfx._srr(keep=PTMIIDNO iciss_09_&sfx year_srr);
    set work.&sfx.srr;
    by PTMIIDNO;
    retain iciss n;
    if first.PTMIIDNO then do; iciss=1; n=0; end;
    n+1;
    if n<=3 then iciss=iciss*srr;
    if last.PTMIIDNO then do;
      year_srr=substr(PTMIIDNO,9,4);
      if iciss<0.9 then iciss_09_&sfx=1; else iciss_09_&sfx=0;   /* 0.9 미만=1 */
      output;
    end;
  run;
%mend;

%iciss(pre=DGOT, sfx=ot);
%iciss(pre=DGDC, sfx=dc);

data save.otdc_srr;
merge save.ot_srr save.dc_srr;
by PTMIIDNO;
if iciss_09_ot=1 or iciss_09_dc=1 then iciss_09=1; else iciss_09=0;
run;

/* 경북 원자료와 결합 (원본의 proc sql left join 대체) */
data save.PTM2022_1;
merge save.PTM2022_GB(in=a) save.otdc_srr;
by PTMIIDNO;
if a;
run;


/**********************************************************
      3단계: 데이터 클리닝 및 28대 중증응급 정의
       퇴실 또는 퇴원 진단코드(구분 1,2) 중 하나라도 해당하면 중증응급
 **********************************************************/

/* &n번 질환, 진단코드 앞 &len자리가 &codes(공백 구분) 중 하나이면 td(퇴실)/cd(퇴원)=1 */
%macro dis(n=, len=, codes=);
  %local i k;
  %do i=1 %to 20;
    %let k=%sysfunc(putn(&i,z2.));
    if strip(vvalue(DGOTDGGB&k)) in ('1','2') and not missing(DGOTDIAG&k)
       and findw("&codes", strip(substr(DGOTDIAG&k,1,&len)), ' ', 't')>0 then emergency_dis_td_&n=1;
    if strip(vvalue(DGDCDGGB&k)) in ('1','2') and not missing(DGDCDIAG&k)
       and findw("&codes", strip(substr(DGDCDIAG&k,1,&len)), ' ', 't')>0 then emergency_dis_cd_&n=1;
  %end;
%mend;

/* [수정] 원본은 libname ss (미정의) 의 PTM2022_1 을 읽고 있었음 -> save */
data work.PTM2022_2;
set save.PTM2022_1;

if missing(PTMIGUCD) then delete; * 환자 거주지 기준;
if ptmiemrt in('41') then delete; * DOA 환자;
if ptmibrtd=. then delete;

if PTMIAKTM in ('-') then PTMIAKTM=""; else PTMIAKTM=PTMIAKTM;
if PTMIDGKD in ('-') then PTMIDGKD=""; else PTMIDGKD=PTMIDGKD;
if PTMIARCF in ('-') then PTMIARCF=""; else PTMIARCF=PTMIARCF;
if PTMIARCS in ('-') then PTMIARCS=""; else PTMIARCS=PTMIARCS;
if PTMIMNSY in ('-') then PTMIMNSY=""; else PTMIMNSY=PTMIMNSY;
if PTMISYM2 in ('-') then PTMISYM2=""; else PTMISYM2=PTMISYM2;
if PTMISYM3 in ('-') then PTMISYM3=""; else PTMISYM3=PTMISYM3;
if PTMIRESP in ('-') then PTMIRESP=""; else PTMIRESP=PTMIRESP;
if PTMIKTS1 in ('-') then PTMIKTS1=""; else PTMIKTS1=PTMIKTS1;
if PTMIKJOB in ('-') then PTMIKJOB=""; else PTMIKJOB=PTMIKJOB;
if PTMIKTS2 in ('-') then PTMIKTS2=""; else PTMIKTS2=PTMIKTS2;
if PTMIAREA in ('-') then PTMIAREA=""; else PTMIAREA=PTMIAREA;
if PTMIMDCD in ('-') then PTMIMDCD=""; else PTMIMDCD=PTMIMDCD;
if PTMIHSDT in ('-') then PTMIHSDT=""; else PTMIHSDT=PTMIHSDT;
if PTMIHSTM in ('-') then PTMIHSTM=""; else PTMIHSTM=PTMIHSTM;
if PTMISDCD in ('-') then PTMISDCD=""; else PTMISDCD=PTMISDCD;
if PTMIEMRT in ('-') then PTMIEMRT=""; else PTMIEMRT=PTMIEMRT;
if PTMIHSRT in ('-') then PTMIHSRT=""; else PTMIHSRT=PTMIHSRT;
if PTMIDEPT in ('-') then PTMIDEPT=""; else PTMIDEPT=PTMIDEPT;
if PTMIDCRT in ('-') then PTMIDCRT=""; else PTMIDCRT=PTMIDCRT;
if PTMIINTP in ('-') then PTMIINTP=""; else PTMIINTP=PTMIINTP;
if PTMIDCTP in ('-') then PTMIDCTP=""; else PTMIDCTP=PTMIDCTP;
/* 원본에서 두 번씩 있던 PTMIMNSY, PTMIRESP 중복 줄은 제거 */
/* 참고: PTMIKTS2 '-' 는 여기서 "" 가 되므로 4단계의 if ptmikts2='-' then ptmikts2=9 는 실행되지 않음(원본과 동일 동작) */

array td {28} emergency_dis_td_1-emergency_dis_td_28;
array cd {28} emergency_dis_cd_1-emergency_dis_cd_28;
array ds {28} emergency_dis_1-emergency_dis_28;

*1 심근경색증(MI);
%dis(n=1,  len=3, codes=I21)
*2 허혈성뇌졸중(IS);
%dis(n=2,  len=3, codes=I63 I64)
*3 뇌실질출혈(CPD);
%dis(n=3,  len=3, codes=I61 I62)
*4 거미막하출혈(SH);
%dis(n=4,  len=3, codes=I60)
*5 중증외상(MT): 2단계 ICISS 결과;
if iciss_09_ot=1 then emergency_dis_td_5=1;
if iciss_09_dc=1 then emergency_dis_cd_5=1;
*6 대동맥박리(AD);
%dis(n=6,  len=4, codes=I710 I711 I713 I715 I718)
*7 담낭담관질환;
%dis(n=7,  len=4, codes=K800 K801 K803 K804 K805 K819 K830 K831)
*8 외과계질환(장중첩/폐색 별도);
%dis(n=8,  len=4, codes=K352 K353 K631 K661)
%dis(n=8,  len=3, codes=K65)
*9 위장관출혈/이물질;
%dis(n=9,  len=4, codes=I850 I864 I983 K226 K250 K252 K254 K256 K260 K262 K264 K266 K920 K921 K922 T181)
*10 기관지출혈/이물질;
%dis(n=10, len=4, codes=R042 R048 R049 T174 T175 T178 T179)
*11 중독(CO포함);
%dis(n=11, len=3, codes=T36 T37 T38 T39 T40 T41 T42 T43 T44 T45 T46 T47 T48 T49 T50 T51 T52 T53 T54 T55 T56 T57 T58 T59 T60 T61 T62 T63 T64 T65)
*12 주산기질환;
%dis(n=12, len=3, codes=O00 O14 O15 O45 O60 O72 O80 O82)
%dis(n=12, len=4, codes=O420 O421 O422 O429 O622)
*13 조산아/저체중아;
%dis(n=13, len=3, codes=P07 P22 P24 P36 P52 P59)
*14 중증화상;
%dis(n=14, len=4, codes=T203 T207 T213 T217 T313 T314 T315 T316 T317 T318 T319)
*15 간질지속상태;
%dis(n=15, len=3, codes=G41)
*16 뇌수막염;
%dis(n=16, len=3, codes=A83 A84 A85 A86 A87 G00 G01 G02 G03 G04 G05 G06 G07)
*17 패혈증;
%dis(n=17, len=4, codes=A021 A227 A241 A267 A400 A401 A402 A403 A404 A405 A406 A407 A408 A409 A410 A411 A412 A413 A414 A419 A427 B007 B377)
*18 당뇨병성 혼수;
%dis(n=18, len=4, codes=E100 E101 E110 E111 E130 E131 E140 E141)
*19 폐색전/DVT;
%dis(n=19, len=4, codes=I260 I269 I802)
*20 부정맥;
%dis(n=20, len=3, codes=I45 I48)
%dis(n=20, len=4, codes=I441 I442 I472 I490 I495 I498 I499)
*21 ARDS/폐부종;
%dis(n=21, len=3, codes=J80 J81 J85 J86 J96)
*22 DIC;
%dis(n=22, len=3, codes=D65)
*23 장중첩/폐색;
%dis(n=23, len=4, codes=K561 K562 K563 K565 K566)
*24 사지절단;
%dis(n=24, len=3, codes=S48 S58 S68 S78 S88 T05)
%dis(n=24, len=4, codes=S980 S981 S982 S983 S984 T060 T061 T062 T063 T064 T065 T066 T067 T068 T116 T136)
*25 급성신부전;
%dis(n=25, len=3, codes=N17)
*26 안과적 응급;
%dis(n=26, len=3, codes=H33 H34 H40 H42)
*27 소생술 후 상태;
%dis(n=27, len=3, codes=I46)
*28 비뇨기과 응급;
%dis(n=28, len=3, codes=N44)
%dis(n=28, len=4, codes=N450 N459)

do j=1 to 28;
  if cd{j}=1 or td{j}=1 then ds{j}=1;   /* 질환별: 퇴실 또는 퇴원 */
end;

emergency_dis_td_s=sum(of emergency_dis_td_1-emergency_dis_td_28);
emergency_dis_cd_s=sum(of emergency_dis_cd_1-emergency_dis_cd_28);
if emergency_dis_td_s>=1 then emergency_dis_td=1;   /* 퇴실 하나라도 중증 */
if emergency_dis_cd_s>=1 then emergency_dis_cd=1;   /* 퇴원 하나라도 중증 */
if emergency_dis_cd=1 or emergency_dis_td=1 then emergency_dis=1;

drop i j;
run;

/* ★ 28대 중증응급 환자만 추출 */
data save.PTM2022_2;
set work.PTM2022_2;
if emergency_dis=1;
run;

/* [수정] 원본은 BY 없이 merge (관측치 순서대로 붙는 one-to-one) -> 데이터가 줄어든 뒤에는 반드시 어긋남.
   최종치료 필요 질환군(첨부 2, ptm_dt3)을 PTMIIDNO 로 결합 */
proc sort data=save.PTM2022_2; by PTMIIDNO; run;
proc sort data=save.ptm_dt3 out=work.ptm_dt3_s; by PTMIIDNO; run;

data save.PTM2022_3;
merge save.PTM2022_2(in=a) work.ptm_dt3_s;
by PTMIIDNO;
if a;
run;

proc freq data=save.PTM2022_3; tables emergency_dis_1-emergency_dis_28 / missing; run;   /* 질환별 건수 확인용 */


/**********************************************************************
  4단계: NEDIS 주요 변수 정의 (원본 로직 그대로, 입력만 save.PTM2022_3)
  - [수정1] 응급실 입실 일자: 대입 변수 오타 PTMIOINDT -> PTMIINDT
  - [수정2] 연령(2) 마지막 else: age_gp -> age_2gp
**********************************************************************/
data save.PTM2022_4;
set save.PTM2022_3;

year=substr(PTMIIDNO,9,4);

* 응급의료기관 종별;
 if PTMIEMCL eq "A" then h_type=1; *권역응급의료센터;
 if PTMIEMCL eq "C" then h_type=2; *지역응급의료센터;
 if PTMIEMCL eq "D" then h_type=3; *지역응급의료기관;

*(응급의료기관지역 기준) 시도;
if ptmiemar in(11680,11740,11305,11500,11620,11215,11530, 11545,11350,11320,
11230,11590,11440,11410,11650,11200,11290,11710,11470,11560,11170,11380,
11110,11140,11260) then hp_area=1; *서울;
else if ptmiemar in(26110,26140,26170,26200,26230,26260,26290,26320,
26350, 26380,26410,26440,26470,26500,26530,26710) then hp_area=2; *부산;
else if ptmiemar in(27110,27140,27170,27200,27230,27260,27290,27710) then hp_area=3; *대구;
else if ptmiemar in(28110,28140,28170,28185,28200,28237,28245,28260,28710,28720) then hp_area=4; *인천;
else if ptmiemar in(29110,29140,29155,29170,29200) then hp_area=5; *광주;
else if ptmiemar in(30110,30140,30170,30200,30230) then hp_area=6; *대전;
else if ptmiemar in(31110,31140,31170,31200,31710) then hp_area=7; *울산;
else if ptmiemar=36110 then hp_area=8; *세종;
else if ptmiemar in(41820,41281,41285,41287,41290,41210,41610,41310,41410, 41570,
41360,41250,41197,41199,41195,41135,41131,41133,41113,41117,41111,41115,41390,
41273,41271,41550,41173,41171,41630,41830,41670,41800,41370,41463,41465, 41461,
41430,41150,41500,41480,41220,41650,41450,41590) then hp_area=9; *경기;
else if ptmiemar in(42150,42820,42170,42230,42210,42800,42830,42750,42130,42810,
42770,42780,42110,42190,42760,42720,42790,42730) then hp_area=10; *강원도;
else if ptmiemar in(43760,43800,43720,43740,43730,43770,43150,43745, 43750,
43111,43112,43114,43113,43130) then hp_area=11; *충북;
else if ptmiemar in(44250,44150,44710,44230,44270,44180,44760,44210,44770,44200,
44810,44131,44133,44790,44825,44800) then hp_area=12; *충남;
else if ptmiemar in(45790,45130,45210,45190,45730,45800,45770,45710,45140,45750,
45740,45113,45111,45180,45720) then hp_area=13; *전북;
else if ptmiemar in(46810,46770,46720,46230,46730,46170,46710,46110,46840,46780,
46150,46910,46130,46870,46830,46890,46880,46800,46900,46860,46820,46790) then hp_area=14; *전남;
else if ptmiemar in(47290,47130,47830,47190,47720,47150,47280,47920,47250,47840,47170,47770,
47760,47210,47230,47900,47940,47930,47730,47820,47750,47850,47111,47113) then hp_area=15; *경북;
else if ptmiemar in(48310,48880,48820,48250,48840,48270,48240,48860,48330,48720,
48170,48740,48125,48127,48123,48121,48129,48220,48850,48730,48870,48890) then hp_area=16; *경남;
else if ptmiemar in(50110,50130) then hp_area=17; *제주;
else hp_area=.;

*(응급의료기관지역 기준) 경상북도 시군구별;
if ptmiemar eq "47111" then hp_gb=1; *포항시남구;
if ptmiemar eq "47113" then hp_gb=2; *포항시북구;
if ptmiemar eq "47130" then hp_gb=3; *경주시;
if ptmiemar eq "47150" then hp_gb=4; *김천시;
if ptmiemar eq "47170" then hp_gb=5; *안동시;
if ptmiemar eq "47190" then hp_gb=6; *구미시;
if ptmiemar eq "47210" then hp_gb=7; *영주시;
if ptmiemar eq "47230" then hp_gb=8; *영천시;
if ptmiemar eq "47250" then hp_gb=9; *상주시;
if ptmiemar eq "47280" then hp_gb=10; *문경시;
if ptmiemar eq "47290" then hp_gb=11; *경산시;
if ptmiemar eq "47720" then hp_gb=12; *군위군;
if ptmiemar eq "47730" then hp_gb=13; *의성군;
if ptmiemar eq "47750" then hp_gb=14; *청송군;
if ptmiemar eq "47760" then hp_gb=15; *영양군;
if ptmiemar eq "47770" then hp_gb=16; *영덕군;
if ptmiemar eq "47820" then hp_gb=17; *청도군;
if ptmiemar eq "47830" then hp_gb=18; *고령군;
if ptmiemar eq "47840" then hp_gb=19; *성주군;
if ptmiemar eq "47850" then hp_gb=20; *칠곡군;
if ptmiemar eq "47900" then hp_gb=21; *예천군;
if ptmiemar eq "47920" then hp_gb=22; *봉화군;
if ptmiemar eq "47930" then hp_gb=23; *울진군;
if ptmiemar eq "47940" then hp_gb=24; *울릉군;

if hp_gb in(1,2) then hp_gb_poh=1; *포항시;

* (응급의료기관지역 기준) 경상북도 6개 진료권;
if hp_gb in(1,2,16,23,24) then hp_hsa_gb=1;  *포항권;
else if hp_gb in(3,11,8,17) then hp_hsa_gb=2;  *경주권;
else if hp_gb in(5,13,14,15) then hp_hsa_gb=3; *안동권;
else if hp_gb in(6,20,12,4,19,18) then hp_hsa_gb=4; *구미권;
else if hp_gb in(7,21,22) then hp_hsa_gb=5; *영주권;
else if hp_gb in(9,10) then hp_hsa_gb=6; *상주권;
else hp_hsa_gb=.;

* (응급의료기관지역 기준) 응급의료권역;
if hp_gb in(5,10,22,15,7,21,13,14) then hp_em_gb=1; *경북안동권;
else if hp_gb in(6,4,20,9) then hp_em_gb=2; *경북구미권;
else if hp_gb in(1,2,3,16,23,24) then hp_em_gb=3; *경북포항권;
else if hp_gb in(11,18,12,19,8,17) then hp_em_gb=4; *대구권;
else hp_em_gb=.;

/************************************************
   (환자주소지 기준) 시도, 시군구, 진료권, 응급의료권역
*************************************************/

* (환자주소지 기준) 시도;
if ptmigucd in(11680,11740,11305,11500,11620,11215,11530,
11545,11350,11320,11230,11590,11440,11410,11650,11200,
11290,11710,11470,11560,11170,11380,11110,11140,11260) then pa_area=1; *서울;
else if ptmigucd in(26110,26140,26170,26200,26230,26260,
26290,26320,26350,26380,26410,26440,26470,26500,26530,26710) then pa_area=2; *부산;
else if ptmigucd in(27110,27140,27170,27200,27230,27260,27290,27710) then pa_area=3; *대구;
else if ptmigucd in(28110,28140,28170,28177,28185,28200,28237,28245,28260,28710,28720) then pa_area=4; *인천;
else if ptmigucd in(29110,29140,29155,29170,29200) then pa_area=5; *광주;
else if ptmigucd in(30110,30140,30170,30200,30230) then pa_area=6; *대전;
else if ptmigucd in(31110,31140,31170,31200,31710) then pa_area=7; *울산;
else if ptmigucd=36110 then pa_area=8; *세종;
else if ptmigucd in(41111,41113,41115,41117,41131,41133,41135,41150,41171,
41173,41190,41195,41197,41199,41210,41220,41250,41271,41273,41281,41285,
41287,41290,41310,41360,41370,41390,41410,41430,41450,41461,41463,41465,
41480,41500,41550,41570,41590,41610,41630,41650,41670,41800,41820,41830) then pa_area=9; *경기;
else if ptmigucd in(42150,42820,42170,42230,42210,42800,42830,42750,42130,
42810,42770,42780,42110,42190,42760,42720,42790,42730) then pa_area=10; *강원도;
else if ptmigucd in(43760,43800,43720,43740,43730,43770,43150,43745,
43750,43111,43112,43114,43113,43130) then pa_area=11; *충북;
else if ptmigucd in(44250,44150,44710,44230,44270,44180,44760,44210,
44770,44200,44810,44131,44133,44790,44825,44800) then pa_area=12; *충남;
else if ptmigucd in(45790,45130,45210,45190,45730,45800,45770,45710,
45140,45750,45740,45113,45111,45180,45720) then pa_area=13; *전북;
else if ptmigucd in(46810,46770,46720,46230,46730,46170,46710,46110,46840,46780,46150,
46910,46130,46870,46830,46890,46880,46800,46900,46860,46820,46790) then pa_area=14; *전남;
else if ptmigucd in(47290,47130,47830,47190,47720,47150,47280,47920,47250,47840,47170,
47770,47760,47210,47230,47900,47940,47930,47730,47820,47750,47850,47111,47113) then pa_area=15; *경북;
else if ptmigucd in(48310,48880,48820,48250,48840,48270,48240,48860,48330,48720,
48170,48740,48125,48127,48123,48121,48129,48220,48850,48730,48870,48890) then pa_area=16; *경남;
else if ptmigucd in(50110,50130) then pa_area=17; *제주;
else pa_area=.;

* (환자주소지 기준) 경상북도 시군구;
if ptmigucd eq "47111" then pa_gb=1; *포항시남구;
if ptmigucd eq "47113" then pa_gb=2; *포항시북구;
if ptmigucd eq "47130" then pa_gb=3; *경주시;
if ptmigucd eq "47150" then pa_gb=4; *김천시;
if ptmigucd eq "47170" then pa_gb=5; *안동시;
if ptmigucd eq "47190" then pa_gb=6; *구미시;
if ptmigucd eq "47210" then pa_gb=7; *영주시;
if ptmigucd eq "47230" then pa_gb=8; *영천시;
if ptmigucd eq "47250" then pa_gb=9; *상주시;
if ptmigucd eq "47280" then pa_gb=10; *문경시;
if ptmigucd eq "47290" then pa_gb=11; *경산시;
if ptmigucd eq "47720" then pa_gb=12; *군위군;
if ptmigucd eq "47730" then pa_gb=13; *의성군;
if ptmigucd eq "47750" then pa_gb=14; *청송군;
if ptmigucd eq "47760" then pa_gb=15; *영양군;
if ptmigucd eq "47770" then pa_gb=16; *영덕군;
if ptmigucd eq "47820" then pa_gb=17; *청도군;
if ptmigucd eq "47830" then pa_gb=18; *고령군;
if ptmigucd eq "47840" then pa_gb=19; *성주군;
if ptmigucd eq "47850" then pa_gb=20; *칠곡군;
if ptmigucd eq "47900" then pa_gb=21; *예천군;
if ptmigucd eq "47920" then pa_gb=22; *봉화군;
if ptmigucd eq "47930" then pa_gb=23; *울진군;
if ptmigucd eq "47940" then pa_gb=24; *울릉군;

if pa_gb in(1,2) then pa_gb_poh=1; *포항시;

* (환자주소지 기준) 경상북도 6개 진료권;
if pa_gb in(1,2,16,23,24) then pa_hsa_gb=1;  *포항권;
else if pa_gb in(3,11,8,17) then pa_hsa_gb=2;  *경주권;
else if pa_gb in(5,13,14,15) then pa_hsa_gb=3; *안동권;
else if pa_gb in(6,20,12,4,19,18) then pa_hsa_gb=4; *구미권;
else if pa_gb in(7,21,22) then pa_hsa_gb=5; *영주권;
else if pa_gb in(9,10) then pa_hsa_gb=6; *상주권;
else pa_hsa_gb=.;

* (환자주소지 기준) 응급의료권역;
if pa_gb in(5,10,22,15,7,21,13,14) then pa_em_gb=1; *경북안동권;
else if pa_gb in(6,4,20,9) then pa_em_gb=2; *경북구미권;
else if pa_gb in(1,2,3,16,23,24) then pa_em_gb=3; *경북포항권;
else if pa_gb in(11,18,12,19,8,17) then pa_em_gb=4; *대구권;
else pa_em_gb=.;

/*경상북도 시군구별 타지역 유출*/
if hp_gb=pa_gb then gb_sigu_out=1; else gb_sigu_out=0; *이탈여부_경상북도 시군구;
if hp_area=pa_area then gb_sido_out=1; else gb_sido_out=0; *이탈여부_경상북도 시도;
if hp_hsa_gb=pa_hsa_gb then gb_6gr=1; else gb_6gr=0; *이탈여부_경상북도 중진료권;
if hp_em_gb=pa_em_gb then gb_4gr=1; else gb_4gr=0; *이탈여부_경상북도 응급의료권역;

/***************************************************
   (응급의료기관지역 기준) 경상북도 권역 및 지역응급의료센터별
 ***************************************************/
if h_type=1 then do;
if hp_gb=5 then hp_center=1;  *안동병원;
else if hp_gb=6 then hp_center=2; *구미차병원;
else if hp_gb=1 then hp_center=3; *포항성모병원(남구);
else hp_center=.;
end;

if h_type=2 then do;
if hp_gb=1 then hp_center2=1; *포항세명기독병원(남구);
else if hp_gb=3 then hp_center2=2; *동국대학교의과대학 경주병원;
else if hp_gb=4 then hp_center2=3; *김천제일병원;
else if hp_gb=5 then hp_center2=4; *안동성소병원;
else if hp_gb=6 then hp_center2=5; *순천향대부속구미병원;
else if hp_gb=10 then hp_center2=6; *(의)동춘의료재단문경제일병원;
else hp_center2=.;
end;

/*응급실 입실 일자 시간*/
/* [수정1] PTMIOINDT -> PTMIINDT (원본 오타: 대입 변수가 잘못되어 '11111111'/'-' 가
   in_mdy 계산에 그대로 들어가던 문제) */
if PTMIINDT in ('11111111', '-') then PTMIINDT=""; else PTMIINDT=PTMIINDT;
if PTMIINTM in ('1111', '-') then PTMIINTM=""; else PTMIINTM=PTMIINTM;
/*응급실 퇴실 일자 시간*/
if PTMIOTDT in ('11111111', '-') then PTMIOTDT=""; else PTMIOTDT=PTMIOTDT;
if PTMIOTTM in ('1111', '-') then PTMIOTTM=""; else PTMIOTTM=PTMIOTTM;
/*발병일자 시간*/
if PTMIAKDT in ('11111111', '-') then PTMIAKDT=""; else PTMIAKDT=PTMIAKDT;
if PTMIAKTM in ('1111', '-') then PTMIAKTM=""; else PTMIAKTM=PTMIAKTM;
/*최초 중증도 분류 일자 시간*/
if PTMIKTDT in ('11111111', '-') then PTMIKTDT=""; else PTMIKTDT=PTMIKTDT;
if PTMIKTTM in ('1111', '-') then PTMIKTTM=""; else PTMIKTTM=PTMIKTTM;
/*입원 일자 시간*/
if PTMIHSDT in ('11111111', '99999999', '-') then PTMIHSDT=""; else PTMIHSDT=PTMIHSDT;
if PTMIHSTM in ('1111', '9999', '-') then PTMIHSTM=""; else PTMIHSTM=PTMIHSTM;
/*퇴원 일자 시간*/
if PTMIDCDT in ('11111111', '99999999', '-') then PTMIDCDT=""; else PTMIDCDT=PTMIDCDT;
if PTMIDCTM in ('1111', '9999', '-') then PTMIDCTM=""; else PTMIDCTM=PTMIDCTM;

ak_mdy = mdy(substr(PTMIAKDT,5,2),substr(PTMIAKDT,7,2),substr(PTMIAKDT,1,4));/*발병날짜*/
in_mdy = mdy(substr(PTMIINDT,5,2),substr(PTMIINDT,7,2),substr(PTMIINDT,1,4));/*응급실내원날짜*/
out_mdy = mdy(substr(PTMIOTDT,5,2),substr(PTMIOTDT,7,2),substr(PTMIOTDT,1,4));/*응급실퇴실날짜*/
hs_mdy = mdy(substr(PTMIHSDT,5,2),substr(PTMIHSDT,7,2),substr(PTMIHSDT,1,4));/*입원날짜*/
hsot_mdy = mdy(substr(PTMIDCDT,5,2),substr(PTMIDCDT,7,2),substr(PTMIDCDT,1,4));/*퇴원날짜*/

ak_hms = hms(substr(PTMIAKTM,1,2),substr(PTMIAKTM,3,2),0);/*발병시간*/
in_hms = hms(substr(PTMIINTM,1,2),substr(PTMIINTM,3,2),0);/*응급실내원시간*/
out_hms = hms(substr(PTMIOTTM,1,2),substr(PTMIOTTM,3,2),0);/*응급실퇴실시간*/
hs_hms = hms(substr(PTMIHSTM,1,2),substr(PTMIHSTM,3,2),0);/*입원시간*/
hsot_hms = hms(substr(ptmidctm,1,2),substr(ptmidctm,3,2),0);/*퇴원시간*/

ak_date_1 = (ak_mdy * 24 * 60 * 60) + ak_hms ;/*발병*/
in_date_1 = (in_mdy * 24 * 60 * 60) + in_hms ;/*응급실입실*/
out_date_1 = (out_mdy * 24 * 60 * 60) + out_hms /*응급실퇴실*/;
hs_date_1 = (hs_mdy * 24 * 60 * 60) + hs_hms ;/*입원*/
hsot_date_1 = (hsot_mdy * 24 * 60 * 60) + hsot_hms ;/*퇴원*/

format ak_date_1 in_date_1 hs_date_1 out_date_1 hsot_date_1 datetime16.;

ak_em_in_m=intck('minute',ak_date_1, in_date_1);/*발병-응급실 내원*/
em_time_m=intck('minute',in_date_1,out_date_1);/*응급실 체류시간*/
inout_time_m=intck('minute',hs_date_1,hsot_date_1);/*입원 체류시간*/

/*응급실 체류시간*/
if em_time_m <120 then emt_time=1;
else if 120<= em_time_m <240 then emt_time=2;
else if 240<= em_time_m <360 then emt_time=3;
else if 360<= em_time_m <480 then emt_time=4;
else if 480<= em_time_m <600 then emt_time=5;
else if 600<= em_time_m <720 then emt_time=6;
else if 720<= em_time_m <1440 then emt_time=7;
else if 1440<= em_time_m  then emt_time=8;

/*발병 후 24시간 이내 응급실 내원한 환자 중에서 발병 후 24시간 이내 입원한 환자 구분*/
if 0<=ak_em_in_m<=1440 then in24=1;else in24=0;
if in24=1 then do;
if PTMIEMRT in (31:38) then hs24=1;else hs24=0;end;

*연령(1);
if ptmibrtd=1 then age_gp=0; *1세 미만;
else if ptmibrtd in(2,3) then age_gp=1; *1~9세;
else if ptmibrtd in(4,5) then age_gp=2; *10~19세;
else if ptmibrtd in(6,7) then age_gp=3; *20~29세;
else if ptmibrtd in(8,9) then age_gp=4; *30~39세;
else if ptmibrtd in(10,11) then age_gp=5; *40~49세;
else if ptmibrtd in(12,13) then age_gp=6; *50~59세;
else if ptmibrtd in(14,15) then age_gp=7; *60~69세;
else if ptmibrtd in(16,17) then age_gp=8; *70~79세;
else if ptmibrtd in(18,19) then age_gp=9; *80~89세;
else if ptmibrtd in(20,21) then age_gp=10; *90~99세;
else if ptmibrtd in(22,23,24,25,26) then age_gp=11; *100~126세 이상;
else age_gp=.;

*연령(2);
/* [수정2] 마지막 else 대상: age_gp -> age_2gp (원본 오타로 age_gp 가 결측 처리됨) */
if age_gp=0 then age_2gp=0; *1세 미만;
else if age_gp=1 then age_2gp=1; *1~9세;
else if age_gp=2 then age_2gp=2; *10~19세;
else if age_gp=3 then age_2gp=3; *20~29세;
else if age_gp=4 then age_2gp=4; *30~39세;
else if age_gp=5 then age_2gp=5; *40~49세;
else if age_gp=6 then age_2gp=6; *50~59세;
else if age_gp=7 then age_2gp=7; *60~69세;
else if age_gp=8 then age_2gp=8; *70~79세;
else if age_gp in(9,10,11) then age_2gp=9; *80세 이상;
else age_2gp=.;

*연령(3);
if ptmibrtd=1 then age_3gp=0; *1세 미만;
else if ptmibrtd in(2,3,4,5) then age_3gp=1; *1~19세 미만;
else if ptmibrtd in(6,7,8,9,10,11,12,13,14) then age_3gp=2; *20~64세;
else if ptmibrtd in(15,16,17,18,19,20,21,22,23,24,25,26) then age_3gp=3; *65세 이상;
else age_3gp=.;

*성별;
if ptmisexx eq "M" then sex=1;
if ptmisexx eq "F" then sex=2;

if ptmiemrt in(11,12,13,14,15,18) then result_b=1; *귀가;
else if ptmiemrt in(21,22,23,24, 25,26,27,28, 29) then result_b=2; *전원;
else if ptmiemrt in(31,32,33,34,38) then result_b=3; *입원;
else if ptmiemrt in(42,43,44,45,48) then result_b=4; *사망;
else if ptmiemrt in(88,99,.) then result_b=5; *기타/미상;

*최초 중등도 분류 결과(2);
if ptmikts1 in(1,2) then ktas_level=1;
else if ptmikts1=3 then ktas_level=2;
else if ptmikts1 in(4,5) then ktas_level=3;
else if ptmikts1 in(8,9) then ktas_level=4;
else ktas_level=.;

*변경된 중증도 분류 결과;
if ptmikts2='-' then ptmikts2=9;
if ptmikts2=1 then c_level=1; *소생;
else if ptmikts2=2 then c_level=2; *긴급;
else if ptmikts2=3 then c_level=3; *응급;
else if ptmikts2=4 then c_level=4; *준응급;
else if ptmikts2=5 then c_level=5; *비응급;
else if ptmikts2 in(8,9) then c_level=6; *기타(분류불가)/미상;
else c_level=.;

*응급실 내원경로;
if ptmiinrt=1 then route=1; *직접내원;
else if ptmiinrt=2 then route=2; *외부에서 전원;
else if ptmiinrt=3 then route=3; *외부에서 의뢰;
else if ptmiinrt in(8,9) then route=4; *기타/미상;
else route=.;

*내원수단;
if ptmiinmn=1 then vehicel=1; *119 구급차;
else if ptmiinmn=2 then vehicel=2; *의료기관 구급차;
else if ptmiinmn=3 then vehicel=3; *기타 구급차;
else if ptmiinmn=4  then vehicel=4; *경찰차 등 공공차량;
else if ptmiinmn=5  then vehicel=5; *항공 이송;
else if ptmiinmn=6  then vehicel=6; *기타 자동차;
else if ptmiinmn=7  then vehicel=7; *도보;
else if ptmiinmn in(8,9)  then vehicel=8; *기타/미상;
else vehicel=.;

if PTMIINRT=1 then do;
if vehicel=1 then inmn=1; else inmn=0; end;/*119구급차 이용*/

*전문의 진료 여부;
if ptmisdcd=1 then major=1;
else if ptmisdcd=2 then major=2;
else if ptmisdcd=3 then major=3;
else if ptmisdcd=4 then major=4;
else if ptmisdcd in(8,9) then major=5;
else major=.;

*전원 사유;
if PTMIEMRT=21 then reason=1;
else if PTMIEMRT=22 then reason=2;
else if PTMIEMRT=23 then reason=3;
else if PTMIEMRT=24 then reason=4;
else if PTMIEMRT=25 then reason=5;
else if PTMIEMRT=26 then reason=6;
else if PTMIEMRT=27 then reason=7;
else if PTMIEMRT=28 then reason=8;
else if PTMIEMRT=29 then reason=9;
else reason=.;

* 입원 후 결과;
if ptmidcrt=1 then final=1;
else if ptmidcrt=2 then  final=2;
else if ptmidcrt=3 then  final=3;
else if ptmidcrt=4 then  final=4;
else if ptmidcrt=5 then  final=5;
else if ptmidcrt=6 then  final=6;
else if ptmidcrt=8 then  final=7;
else final=.;

if ptmidctp=1 then trans_go=1;
else if ptmidctp=2 then trans_go=2;
else if ptmidctp in(3,4,5) then trans_go=3;
else if ptmidctp in(8,9) then trans_go=4;
else trans_go=.;

*원내사망률;
if result_b=4 or final=4 then death=1;

*입원치료제공률;
if emergency_dis=1 and result_b=3 then enter_hp=1;

if PTMIEMRT in (21:29) then PTMIEMRT_1_t=1;else PTMIEMRT_1_t=0;/*전원 여부*/
if ptmiinrt = 2 then do;/*재전원 여부*/
if PTMIEMRT_1_t =1 then PTMIEMRT_1_RT=1; else if PTMIEMRT_1_t =0 then PTMIEMRT_1_RT=0;end;

/*급성기 중증응급질환*/
acute_em_dis=sum(emergency_dis_1, emergency_dis_2, emergency_dis_3, emergency_dis_4, emergency_dis_5);

/*급성기 중증응급질환이 하나라도 있는 사람*/
if acute_em_dis>=1 then acute_em_5dis=1;

/*최종치료제공*/
/*분모*/
if PTMIKTS1 in (1,2,3) or PTMIKTS2 in (1,2,3) then KTS=1;else KTS=0;
if KTS=1 and em_dt=1 then KTS_DT=1; *(분모)최종치료 필요사례수;

/*분자*/
if KTS_DT=1 then do;
if PTMIEMRT in ('42', '43', '44', '45', '48', '13', '31', '32', '33', '34', '38') then EMRT_DT=1; else  EMRT_DT=0;
end;

/*발병 24이내 급성기 평균 내원시간*/
if acute_em_5dis=1 then do;
if hs24=1 then do;
if ak_em_in_m<=30 then em_time30=1;else em_time30=0; end; end;

/*대구광역시, 대구 상급종합병원 정의*/

*대구 시군구 정의(응급의료기관 기준);
if ptmiemar='27110' then daegu=1; *중구, 경북대학교병원;
if ptmiemar='27140' then daegu=2; *동구, 대구파티마병원;
if ptmiemar='27170' then daegu=3; *서구;
if ptmiemar='27200' then daegu=4; *남구, 영남대학교병원, 가톨릭대학교병원;
if ptmiemar='27230' then daegu=5; *북구 칠곡경북대학교병원;
if ptmiemar='27260' then daegu=6; *수성구;
if ptmiemar='27290' then daegu=7; *달서구, 계명대학교 동산병원;
if ptmiemar='27710' then daegu=8; *달성군;

*대구광역시 권역 및 지역응급의료센터(상급종합병원급, 파티마제외);
if h_type in(1,2) then do;
if daegu in(1,4,5,7) then daegu_top=1;
else daegu_top=0; end;

* 대구, 각 응급의료기관별 정의;
if h_type=1 and daegu=1 then gb_hp=1; else gb_hp=0; *경북대학교병원;
if h_type=1 and daegu=4 then gb_hp_yu=1; else gb_hp_yu=0; *영남대학교병원;
if h_type=2 and daegu=4 then gb_hp_ga=1; else gb_hp_ga=0; *가톨릭;
if h_type=2 and daegu=5 then gb_hp_ch=1; else gb_hp_ch=0; *칠곡;
if h_type=2 and daegu=7 then gb_hp_gae=1; else gb_hp_gae=0; *계명대;
if h_type=2 and daegu=2 then gb_hp_pati=1; else gb_hp_pati=0; *대구파티마;

* 파티마 포함 응급의료기관(종합병원급 이상);
if gb_hp=1 or gb_hp_yu=1 or gb_hp_ga=1 or gb_hp_ch=1 or gb_hp_gae=1 or gb_hp_pati=1 then ttop_dg=1;
else ttop_dg=0;

* 경북 중증환자 중, 대구병원으로 유출(전체);
if pa_area=15 and emergency_dis=1 then do;
if hp_area=3 then gb_dg_go=1;
else gb_dg_go=0; end;

* 경북 중증환자 중, 대구병원으로 유출(종합병원급 이상);
if pa_area=15 and emergency_dis=1 then do;
if ttop_dg=1 then gb_dg_topgo=1;
else gb_dg_topgo=0; end;

if pa_area in(1:2) or pa_area in(4:17) then daegu_ox=1; *대구사람x;
else if pa_area=3 then daegu_ox=0; *대구사람;
else daegu_ox=.;

run;


/**********************************************************************
  5단계: 최종 변수 정리 (drop / label) + 경북 데이터셋 추출
  - [수정3] pa_area/hp_area 추출은 범위 삭제 대신 WHERE 사용 (결측 잔존 방지)
**********************************************************************/
data save.PTM2022_5;
set save.PTM2022_4;

drop
PTMIOINDT ak_mdy in_mdy out_mdy hs_mdy hsot_mdy ak_hms in_hms out_hms hs_hms hsot_hms ak_date_1 in_date_1 out_date_1
 hs_date_1 hsot_date_1 inout_time_m in24 c_level KTS ptmihsdt ptmihstm ptmidcrt
ptmimnsy ptmimssr ptmisym2 ptmisys2 ptmisym3 ptmisys3 ptmiemsy ptmiresp ptmiktdt ptmikttm ptmikjob ptmiarea ptmimdcd ptmidept
ptmiotdt ptmiottm ptmidcdt ptmidctm ptmiintp ptmidctp acute_em_dis age_gp ptmiiukd ptmidgkd ptmiarcf ptmiarcs em_dt;

label
year="연도"
ptmiidno="랜덤매칭키"
ptmiemar ="응급의료기관지역(시군구코드)"
ptmiemcl="응급의료기관종별"
ptmiemnm	="응급의료기관명"
ptmiindt="내원일자"
ptmiintm="내원시간"
ptmibrtd="연령"
ptmisexx="성별"
ptmigucd="환자주소지(시군구코드)"
ptmiakdt="발병일자"
ptmiaktm="발병시간"
ptmiinrt="내원경로"
ptmiinmn="내원수단"
ptmikts1="최초 중증도 분류 결과"
ptmikts2="변경된 중증도 분류 결과"
ptmisdcd="전문의 진료 여부"
ptmiemrt="응급진료결과"
ptmihsrt="입원경로"

h_type="(재분류)응급의료기관종별"
hp_area="(기관기준)시도"
hp_gb="(기관기준)시군구"
hp_hsa_gb="(기관기준)중진료권"
hp_em_gb="(기관기준)응급의료권역"

pa_area="(환자기준)시도"
pa_gb="(환자기준)시군구"
pa_hsa_gb="(환자기준)중진료권"
pa_em_gb="(환자기준)응급의료권역"

gb_sigu_out="(유출)시군구"
gb_sido_out="(유출)시도"
gb_6gr="(유출)중진료권"
gb_4gr="(유출)응급의료권역"

hp_center='경북권역응급의료센터'
hp_center2='경북지역응급의료센터'
em_time30='급성기_30분내 도착률'

ak_em_in_m="발병후내원소요시간"
emt_time="응급실 체류시간(그룹)"
hs24="발병후24시간이내 내원한 환자 중 입원"

age_2gp="연령(2)"
age_3gp="연령(3)"
sex="성별"

result_b="응급진료결과"
ktas_level="최초중증도"
route="응급실 내원경로"
vehicel="내원수단"
inmn="119구급차이용"
major="전문의진료여부"
reason="전원사유"
final="입원 후 결과"
death="원내사망"
enter_hp="중증_입원치료"

PTMIEMRT_1_t="전원여부"
PTMIEMRT_1_rt="재전원여부"

acute_em_5dis="(급성기)중증응급환자"
emergency_dis="중증응급환자"

daegu='대구시군구정의(응급의료기관 기준)'
daegu_top='대구상급종합병원'
ttop_dg='(파티마포함)대구응급의료기관'
gb_hp='경북대학교병원'
gb_hp_yu='영남대학교병원'
gb_hp_ga='대구가톨릭대학교병원'
gb_hp_ch='칠곡경북대학교병원'
gb_hp_gae='계명대학교 동산병원'
gb_hp_pati='대구파티마병원'

daegu_ox='대구사람유무'
gb_dg_go='(전체)경북사람_대구병원'
gb_dg_topgo='(종합병원급이상)경북사람_대구병원'

hp_gb_poh='(응급의료기관 기준)포항시'
pa_gb_poh='(환자거주지 기준)포항시'

KTS_DT='(분모)최종치료 필요사례수'
EMRT_DT='최종치료 제공사례수 중 1번'
EM_DT='(분자)최종치료 제공사례수';

run;

/* [주의] 0단계에서 환자 거주지(PTMIGUCD) 기준으로만 경북을 추출했으므로 save.PTM2022_5는
   이미 전부 pa_area=15 이다. 따라서 아래 save.pa_area는 save.PTM2022_5와 사실상 동일하고,
   save.hp_area(hp_area=15)는 "경북 거주자이면서 경북 병원 이용"만 잡히는 부분집합이며
   경북 소재 응급의료기관의 전체 이용 현황과는 다르다(타 시도 거주자의 경북 병원 이용 제외).
   경북 소재 병원 전체 이용 현황이 필요하면 0단계 조건에 PTMIEMAR 기준을 추가할 것. */
data save.pa_area; set save.PTM2022_5; where pa_area=15; run;
data save.hp_area; set save.PTM2022_5; where hp_area=15; run;
