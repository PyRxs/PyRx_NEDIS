/**********************************************************************
  NEDIS 2022 : 경상북도 + 28대 중증응급 축소 버전 (0~3단계)
  - 4~5단계(주요 변수 정의)는 기존 코드를 그대로 쓰되 파일 하단의 "4~5단계 수정 사항"만 반영
  - 흐름
      0단계  원자료 import -> 경북(환자 거주지 OR 응급의료기관 소재지)만 추출  -> save.PTM2022_GB
      2단계  중증외상(ICISS/SRR 2020) 산출 (경북 데이터에만 수행)              -> save.otdc_srr
      3단계  클리닝 + 28대 중증응급 정의 후 emergency_dis=1 만 추출            -> save.PTM2022_3
**********************************************************************/

libname save '\\172.30.1.200\경북지원단\경북지원단\공공보건의료 협력체계 구축사업 기초조사 위탁 용역\응급 NEDIS 임시';

/*--------------------------------------------------------------------
  0단계: import 후 경북만 추출
   - 환자 거주지(PTMIGUCD) 또는 응급의료기관 소재지(PTMIEMAR)가 47xxx
     (pa_area=15 / hp_area=15 두 최종 데이터셋과 gb_dg_go(경북민->대구병원)를 모두 커버)
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
length _g _e $20;
_g=strip(vvalue(PTMIGUCD));   /* 숫자/문자형 어느 쪽으로 읽혀도 동작 */
_e=strip(vvalue(PTMIEMAR));
if substr(_g,1,2)='47' or substr(_e,1,2)='47';
drop _g _e;
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
  4~5단계: 기존 코드에서 아래 4곳만 수정 (입력은 그대로 save.PTM2022_3)
**********************************************************************/
/* (1) 응급실 입실 일자 시간: 대입 변수 오타 (PTMIOINDT -> PTMIINDT)
       [원본] if PTMIINDT in ('11111111', '-') then PTMIOINDT=""; else PTMIINDT=PTMIINDT;
       [수정] if PTMIINDT in ('11111111', '-') then PTMIINDT=""; else PTMIINDT=PTMIINDT;
       -> 원본은 '11111111'/'-' 가 그대로 남아 in_mdy 계산에 잘못 들어감 */

/* (2) 연령(2) 의 마지막 else: age_2gp 가 아니라 age_gp 를 결측으로 만들고 있음
       [원본] else age_gp=.;      (age_2gp 블록 마지막 줄)
       [수정] else age_2gp=.;                                              */

/* (3) 최종 경북 데이터셋 추출: 범위 삭제 방식은 pa_area/hp_area 결측도 남김 -> where 로 변경
       data save.pa_area; set save.PTM2022_5; where pa_area=15; run;
       data save.hp_area; set save.PTM2022_5; where hp_area=15; run;        */

/* (4) 4단계 시작부 dataset 이름은 그대로:  data save.PTM2022_4; set save.PTM2022_3; ...  */
