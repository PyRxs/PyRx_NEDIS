/**********************************************************************
  NEDIS 2022 : 경상북도 + 28대 중증응급 축소 버전 (0~5단계)
  - 실제 원자료: EMIHPTMI_2022.csv (공식 변수 44개 + dgotdiag/dgdcdiag 01~20 + final_need2/final_prv2)
  - 2017~2021 파이프라인과의 차이점 (원자료 공식 변수설명서 기준으로 확인/반영):
      1) PTMIIDNO(랜덤매칭키)가 이 파일에는 없음 -> 0단계에서 행번호로 합성한 PTMIIDNO를
         생성해서 이후 단계(정렬/병합 키)는 전부 그대로 사용 (매크로/코드 수정 불필요)
      2) 원본의 save.ptm_dt3(최종치료 필요 질환군, 첨부2) 외부 병합 단계는 제거함.
         원자료에 이미 final_need2/final_prv2(최종치료 필요/제공 사례, 경북 소재 기관 한정)가
         제공되지만, 이번 분석 목적(질환별/대구 유출)과는 무관한 별개 지표라 5단계에서 drop함
         (필요해지면 별도로 다시 설계해서 살릴 것)
      3) PTMIEMCL(응급의료기관종별) 값이 'A'/'C'/'D' 코드가 아니라 '권역응급의료센터' 같은
         한글 텍스트로 제공됨 -> 4단계 h_type 판정을 index() 부분일치로 변경
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
         (PTMIEMNM은 실제 기관명이 아니라 "기관식별코드 대체"(익명 코드)라서, 이 6개 외
          다른 병원을 보려면 그 병원의 익명 코드값을 먼저 알아내야 함)
**********************************************************************/

libname save '\\172.30.1.200\경북지원단\경북지원단\공공보건의료 협력체계 구축사업 기초조사 위탁 용역\응급 NEDIS 임시';

/*--------------------------------------------------------------------
  0단계: import 후 경북만 추출
   - PROC IMPORT(GUESSINGROWS) 대신 INFILE/INPUT을 직접 선언한 1-pass 방식으로 변경.
     '-'/'1111'류 결측 코드가 들어올 수 있는 날짜·시간·분류 필드는 전부 문자형으로 지정해서
     GUESSINGROWS 스캔 자체를 없앰(더 빠르고, 타입 오추정으로 인한 invalid data 오류도 없음).
   - PTMIIDNO가 원자료에 없어서, 행번호를 그대로 PTMIIDNO로 합성해 이후 단계 호환.
   - 환자 거주지(PTMIGUCD)가 47xxx인 건만 남김 (응급의료기관 소재지는 보지 않음
     -> 경북 밖 병원을 이용한 경북 거주자의 대구 유출(gb_dg_go) 등, 응급의료기관
        소재지 기준 분석이 필요해지면 이 조건에 PTMIEMAR 조건을 다시 추가할 것)
--------------------------------------------------------------------*/
data work.PTM2022_raw;
infile "\\172.30.1.200\경북지원단\경북지원단\경상북도 응급의료지원단\NEDIS\JE20241103\JE20241103\EMIHPTMI_2022.csv"
delimiter=',' MISSOVER DSD lrecl=32767 firstobs=2;
informat
 ptmiemar   best32.
 ptmiemcl   $16.
 ptmiemnm   best32.
 ptmiindt   $8.      /* '-'/'11111111' 대비 문자형 (원본 numeric 추정 시 invalid data 발생) */
 ptmiintm   $4.      /* '-'/'1111' 대비 문자형 */
 ptmibrtd   best32.
 ptmisexx   $1.
 ptmigucd   $5.
 ptmiiukd   best32.
 ptmiakdt   $8.      /* '-' 대비 문자형 (752385행부터 '-' 등장, 이번 오류 원인 컬럼) */
 ptmiaktm   $4.      /* '-' 대비 문자형 (위와 동일 원인) */
 ptmidgkd   $1.      /* '-' 대비 문자형 */
 ptmiarcf   $1.
 ptmiarcs   $2.
 ptmiinrt   best32.
 ptmiinmn   best32.
 ptmimnsy   $8.
 ptmimssr   best32.
 ptmisym2   $8.
 ptmisys2   best32.
 ptmisym3   $8.
 ptmisys3   best32.
 ptmiemsy   $1.
 ptmiresp   $1.
 ptmikts1   $1.      /* '-' 대비 문자형 */
 ptmiktdt   $8.      /* '-'/'11111111' 대비 문자형 */
 ptmikttm   $4.      /* '-'/'1111' 대비 문자형 */
 ptmikjob   $1.
 ptmikts2   $1.
 ptmiarea   $1.
 ptmimdcd   $1.
 ptmisdcd   $1.
 ptmiemrt   $2.
 ptmihsrt   $2.
 ptmidept   $2.
 ptmiotdt   $8.      /* '-'/'11111111' 대비 문자형 */
 ptmiottm   $4.      /* '-'/'1111' 대비 문자형 */
 ptmihsdt   $8.
 ptmihstm   $4.
 ptmidcrt   $1.
 ptmidcdt   $8.
 ptmidctm   $4.
 ptmiintp   $1.
 ptmidctp   $1.
 VAR_PAT_REG_NO best32.
 dgotdiag01 $6. dgotdggb01 best32. dgotdiag02 $6. dgotdggb02 best32.
 dgotdiag03 $6. dgotdggb03 best32. dgotdiag04 $6. dgotdggb04 best32.
 dgotdiag05 $6. dgotdggb05 best32. dgotdiag06 $6. dgotdggb06 best32.
 dgotdiag07 $6. dgotdggb07 best32. dgotdiag08 $6. dgotdggb08 best32.
 dgotdiag09 $6. dgotdggb09 best32. dgotdiag10 $6. dgotdggb10 best32.
 dgotdiag11 $6. dgotdggb11 best32. dgotdiag12 $6. dgotdggb12 best32.
 dgotdiag13 $6. dgotdggb13 best32. dgotdiag14 $6. dgotdggb14 best32.
 dgotdiag15 $6. dgotdggb15 best32. dgotdiag16 $6. dgotdggb16 best32.
 dgotdiag17 $6. dgotdggb17 best32. dgotdiag18 $6. dgotdggb18 best32.
 dgotdiag19 $6. dgotdggb19 best32. dgotdiag20 $6. dgotdggb20 best32.
 dgdcdiag01 $6. dgdcdggb01 best32. dgdcdiag02 $6. dgdcdggb02 best32.
 dgdcdiag03 $6. dgdcdggb03 best32. dgdcdiag04 $6. dgdcdggb04 best32.
 dgdcdiag05 $6. dgdcdggb05 best32. dgdcdiag06 $6. dgdcdggb06 best32.
 dgdcdiag07 $6. dgdcdggb07 best32. dgdcdiag08 $6. dgdcdggb08 best32.
 dgdcdiag09 $6. dgdcdggb09 best32. dgdcdiag10 $6. dgdcdggb10 best32.
 dgdcdiag11 $6. dgdcdggb11 best32. dgdcdiag12 $6. dgdcdggb12 best32.
 dgdcdiag13 $6. dgdcdggb13 best32. dgdcdiag14 $6. dgdcdggb14 best32.
 dgdcdiag15 $6. dgdcdggb15 best32. dgdcdiag16 $6. dgdcdggb16 best32.
 dgdcdiag17 $6. dgdcdggb17 best32. dgdcdiag18 $6. dgdcdggb18 best32.
 dgdcdiag19 $6. dgdcdggb19 best32. dgdcdiag20 $6. dgdcdggb20 best32.
 final_need2 $1.
 final_prv2  $1.
;
input
 ptmiemar ptmiemcl $ ptmiemnm ptmiindt $ ptmiintm $ ptmibrtd ptmisexx $ ptmigucd $ ptmiiukd
 ptmiakdt $ ptmiaktm $ ptmidgkd $ ptmiarcf $ ptmiarcs $ ptmiinrt ptmiinmn ptmimnsy $ ptmimssr
 ptmisym2 $ ptmisys2 ptmisym3 $ ptmisys3 ptmiemsy $ ptmiresp $ ptmikts1 $ ptmiktdt $ ptmikttm $
 ptmikjob $ ptmikts2 $ ptmiarea $ ptmimdcd $ ptmisdcd $ ptmiemrt $ ptmihsrt $ ptmidept $
 ptmiotdt $ ptmiottm $ ptmihsdt $ ptmihstm $ ptmidcrt $ ptmidcdt $ ptmidctm $ ptmiintp $ ptmidctp $
 VAR_PAT_REG_NO
 dgotdiag01 $ dgotdggb01 dgotdiag02 $ dgotdggb02 dgotdiag03 $ dgotdggb03 dgotdiag04 $ dgotdggb04
 dgotdiag05 $ dgotdggb05 dgotdiag06 $ dgotdggb06 dgotdiag07 $ dgotdggb07 dgotdiag08 $ dgotdggb08
 dgotdiag09 $ dgotdggb09 dgotdiag10 $ dgotdggb10 dgotdiag11 $ dgotdggb11 dgotdiag12 $ dgotdggb12
 dgotdiag13 $ dgotdggb13 dgotdiag14 $ dgotdggb14 dgotdiag15 $ dgotdggb15 dgotdiag16 $ dgotdggb16
 dgotdiag17 $ dgotdggb17 dgotdiag18 $ dgotdggb18 dgotdiag19 $ dgotdggb19 dgotdiag20 $ dgotdggb20
 dgdcdiag01 $ dgdcdggb01 dgdcdiag02 $ dgdcdggb02 dgdcdiag03 $ dgdcdggb03 dgdcdiag04 $ dgdcdggb04
 dgdcdiag05 $ dgdcdggb05 dgdcdiag06 $ dgdcdggb06 dgdcdiag07 $ dgdcdggb07 dgdcdiag08 $ dgdcdggb08
 dgdcdiag09 $ dgdcdggb09 dgdcdiag10 $ dgdcdggb10 dgdcdiag11 $ dgdcdggb11 dgdcdiag12 $ dgdcdggb12
 dgdcdiag13 $ dgdcdggb13 dgdcdiag14 $ dgdcdggb14 dgdcdiag15 $ dgdcdggb15 dgdcdiag16 $ dgdcdggb16
 dgdcdiag17 $ dgdcdggb17 dgdcdiag18 $ dgdcdggb18 dgdcdiag19 $ dgdcdggb19 dgdcdiag20 $ dgdcdggb20
 final_need2 $ final_prv2 $
;
PTMIIDNO = _n_;   /* 원자료에 없는 랜덤매칭키를 행번호로 합성 (2022년 단일 파일이라 그룹핑용으로 충분) */
run;

data save.PTM2022_GB;
set work.PTM2022_raw;
if substr(strip(ptmigucd),1,2)='47';
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

/* [수정] 원본은 여기서 save.ptm_dt3(최종치료 필요 질환군, 첨부2)를 PTMIIDNO로 병합했으나,
   2022 원자료는 이미 final_need2/final_prv2(최종치료 필요/제공 사례, 경북 소재 기관 한정)를
   자체적으로 제공하므로 외부 병합이 불필요함 -> 그대로 통과만 시킴 */
proc sort data=save.PTM2022_2; by PTMIIDNO; run;

data save.PTM2022_3;
set save.PTM2022_2;
run;

proc freq data=save.PTM2022_3; tables emergency_dis_1-emergency_dis_28 / missing; run;   /* 질환별 건수 확인용 */


/**********************************************************************
  4단계: 유출 현황 분석에 필요한 변수만 정의 (지역/진료권/응급의료권역, 대구 특정병원)
  - 목표 분석 3가지(1.질환별 유출 2.대구 소재 병원 유출 3.대구 특정병원 유출)에
    불필요한 연령/성별/내원경로/체류시간/전원사유/사망률/최종치료제공률 등은 전부 제외.
    (원본 4단계 전체 로직은 git 이력에서 확인 가능)
**********************************************************************/
data save.PTM2022_4;
set save.PTM2022_3;

/* [수정] PTMIIDNO는 0단계에서 합성한 행번호라 연도 정보가 없음 -> 2022 단일 파일이므로 상수로 지정 */
year=2022;

* 응급의료기관 종별;
/* [수정] 이 원자료의 PTMIEMCL은 'A'/'C'/'D' 코드가 아니라 '지역응급의료센터' 같은 한글 텍스트로
   제공됨(로그에서 '지역응급의료센터','지역응급의료기관' 실측 확인). 정확한 전체 문자열을 몰라도
   되도록 부분일치(index)로 판정. 분류가 3종 외에 더 있다면 h_type이 결측(.)으로 남으니
   proc freq로 ptmiemcl 분포를 한 번 확인해볼 것 */
 if index(ptmiemcl,'권역')>0 then h_type=1; *권역응급의료센터;
 else if index(ptmiemcl,'지역응급의료센터')>0 then h_type=2; *지역응급의료센터;
 else if index(ptmiemcl,'지역응급의료기관')>0 then h_type=3; *지역응급의료기관;
 else h_type=.;

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

/* [삭제] 경북 자체 권역/지역센터 특정병원 구분(hp_center/hp_center2), 발병~내원 시간 계산,
   연령/성별, 응급진료결과/중증도/내원경로/전원사유/사망률/최종치료제공률 등은 이번 3가지
   목표 분석(질환별 유출, 대구 소재 병원 유출, 대구 특정병원 유출)에 쓰이지 않아 전부 제외함 */

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
  - 목표 분석 3가지에 쓰이지 않는 원자료 원본 컬럼(연령/성별/내원경로/일시/최종치료
    필요·제공사례 등)은 전부 drop하여 용량을 최대한 줄임
**********************************************************************/
data save.PTM2022_5;
set save.PTM2022_4;

drop
ptmiindt ptmiintm ptmibrtd ptmisexx ptmiiukd ptmiakdt ptmiaktm ptmidgkd ptmiarcf ptmiarcs
ptmiinrt ptmiinmn ptmimnsy ptmimssr ptmisym2 ptmisys2 ptmisym3 ptmisys3 ptmiemsy ptmiresp
ptmikts1 ptmiktdt ptmikttm ptmikjob ptmikts2 ptmiarea ptmimdcd ptmisdcd ptmiemrt ptmihsrt
ptmidept ptmiotdt ptmiottm ptmihsdt ptmihstm ptmidcrt ptmidcdt ptmidctm ptmiintp ptmidctp
final_need2 final_prv2;

label
year="연도(2022 고정)"
ptmiidno="행 기반 합성 매칭키(원자료에 실제 랜덤매칭키 없음)"
ptmiemar="응급의료기관지역(시군구코드)"
ptmiemcl="응급의료기관종별"
ptmiemnm="응급의료기관 식별코드(익명화, 실제 기관명 아님)"
ptmigucd="환자주소지(시군구코드)"

h_type="(재분류)응급의료기관종별"
hp_area="(기관기준)시도"
hp_gb="(기관기준)시군구"
hp_gb_poh='(응급의료기관 기준)포항시'
hp_hsa_gb="(기관기준)중진료권"
hp_em_gb="(기관기준)응급의료권역"

pa_area="(환자기준)시도"
pa_gb="(환자기준)시군구"
pa_gb_poh='(환자거주지 기준)포항시'
pa_hsa_gb="(환자기준)중진료권"
pa_em_gb="(환자기준)응급의료권역"

gb_sigu_out="(1=잔류,0=유출)시군구"
gb_sido_out="(1=잔류,0=유출)시도"
gb_6gr="(1=잔류,0=유출)중진료권"
gb_4gr="(1=잔류,0=유출)응급의료권역"

emergency_dis="중증응급환자(28대 질환 중 하나라도 해당)"

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
gb_dg_go='(전체)경북 중증환자_대구병원 유출'
gb_dg_topgo='(종합병원급이상)경북 중증환자_대구병원 유출';

run;

/* [주의] 0단계에서 환자 거주지(PTMIGUCD) 기준으로만 경북을 추출했으므로 save.PTM2022_5는
   이미 전부 pa_area=15 이다. 따라서 아래 save.pa_area는 save.PTM2022_5와 사실상 동일하고,
   save.hp_area(hp_area=15)는 "경북 거주자이면서 경북 병원 이용"만 잡히는 부분집합이며
   경북 소재 응급의료기관의 전체 이용 현황과는 다르다(타 시도 거주자의 경북 병원 이용 제외).
   경북 소재 병원 전체 이용 현황이 필요하면 0단계 조건에 PTMIEMAR 기준을 추가할 것. */
data save.pa_area; set save.PTM2022_5; where pa_area=15; run;
data save.hp_area; set save.PTM2022_5; where hp_area=15; run;


/**********************************************************************
  6단계: 결과표 산출
   1) 질환별 유출 현황(%)
   2) 주산기질환(12)/조산아·저체중아(13) - 대구광역시 유출 비율, 대구 6개 특정병원 유출 비율
  - 입력: save.pa_area (환자 거주지=경북. 0단계 필터로 save.PTM2022_5와 사실상 동일)
  - "유출" = 응급의료기관 소재 시도(hp_area) ≠ 환자 거주지 시도(pa_area), 즉 gb_sido_out=0
  - out_pct(전체 환자 대비 유출율)와 별도로, daegu/top6는
      "_of_total" = 그 질환 전체 환자 대비 비율
      "_of_out"   = 그 질환의 "유출" 환자만 대비 비율(유출 가운데 대구/대구6병원 비중)
    두 가지를 같이 냈으니 PDF 표의 정의와 맞는 쪽으로 골라 쓸 것
**********************************************************************/

proc format;
value dfmt
1='심근경색증' 2='허혈성뇌졸중' 3='뇌실질출혈' 4='거미막하출혈' 5='중증외상'
6='대동맥박리' 7='담낭담관질환' 8='외과계질환(장중첩/폐색 별도)' 9='위장관출혈/이물질'
10='기관지출혈/이물질' 11='중독(CO포함)' 12='주산기질환' 13='조산아/저체중아'
14='중증화상' 15='간질지속상태' 16='뇌수막염' 17='패혈증' 18='당뇨병성혼수'
19='폐색전/DVT' 20='부정맥' 21='ARDS/폐부종' 22='DIC' 23='장중첩/폐색'
24='사지절단' 25='급성신부전' 26='안과적응급' 27='소생술후상태' 28='비뇨기과응급';
run;

/* 1) 질환별 유출 현황(%) */
data work.dis_outflow;
set save.pa_area end=eof;
array ds{28} emergency_dis_1-emergency_dis_28;
array tot{28} _temporary_ (28*0);
array outn{28} _temporary_ (28*0);
do i=1 to 28;
  if ds{i}=1 then do;
    tot{i}+1;
    if gb_sido_out=0 then outn{i}+1;
  end;
end;
if eof then do i=1 to 28;
  disease_no=i;
  disease=put(i,dfmt.);
  total_n=tot{i};
  out_n=outn{i};
  out_pct=ifn(total_n>0, round(out_n/total_n*100,0.1), .);
  output;
end;
keep disease_no disease total_n out_n out_pct;
run;

proc print data=work.dis_outflow noobs label;
var disease_no disease total_n out_n out_pct;
label disease_no='번호' disease='질환명' total_n='전체 환자수' out_n='유출 건수(경북 밖 이용)' out_pct='유출율(%)';
run;

/* 2) 주산기질환(12)/조산아·저체중아(13): 대구 유출, 대구 6개 특정병원 유출 비율 */
data work.perinatal_daegu;
set save.pa_area end=eof;
array pd{2} emergency_dis_12 emergency_dis_13;
array tot{2} _temporary_ (2*0);
array outn{2} _temporary_ (2*0);
array dgn{2} _temporary_ (2*0);
array topn{2} _temporary_ (2*0);
do i=1 to 2;
  if pd{i}=1 then do;
    tot{i}+1;
    if gb_sido_out=0 then outn{i}+1;
    if hp_area=3 then dgn{i}+1;    *대구광역시 소재 병원;
    if ttop_dg=1 then topn{i}+1;   *대구 6개 특정병원(경북대/영남대/가톨릭대/칠곡경북대/계명대동산/대구파티마);
  end;
end;
if eof then do i=1 to 2;
  disease_no=(i=1)*12+(i=2)*13;
  disease=put(disease_no,dfmt.);
  total_n=tot{i};
  out_n=outn{i};
  daegu_n=dgn{i};
  top6_n=topn{i};
  out_pct            = ifn(total_n>0, round(out_n/total_n*100,0.1), .);
  daegu_pct_of_total = ifn(total_n>0, round(daegu_n/total_n*100,0.1), .);
  daegu_pct_of_out   = ifn(out_n>0,   round(daegu_n/out_n*100,0.1),   .);
  top6_pct_of_total  = ifn(total_n>0, round(top6_n/total_n*100,0.1), .);
  top6_pct_of_out    = ifn(out_n>0,   round(top6_n/out_n*100,0.1),   .);
  output;
end;
keep disease_no disease total_n out_n daegu_n top6_n out_pct
     daegu_pct_of_total daegu_pct_of_out top6_pct_of_total top6_pct_of_out;
run;

proc print data=work.perinatal_daegu noobs label;
label disease_no='번호' disease='질환명' total_n='전체 환자수' out_n='유출 건수'
      daegu_n='대구 소재병원 이용 건수' top6_n='대구 6개 특정병원 이용 건수'
      out_pct='유출율(%, 전체대비)'
      daegu_pct_of_total='대구 유출율(%, 전체대비)' daegu_pct_of_out='대구 유출율(%, 유출대비) *확정 지표*'
      top6_pct_of_total='대구6병원 유출율(%, 전체대비)' top6_pct_of_out='대구6병원 유출율(%, 유출대비) *확정 지표*';
run;

/* 3) 중증응급환자 전체(28대 질환 통합) - 유출 건수 대비 대구 종합병원급 이상(6개 병원) 유출률
   [확정] 분모=유출 건수(gb_sido_out=0), 분자=그 중 대구 종합병원급 이상(ttop_dg=1, =6개 병원)
   전체 + 6개 진료권(pa_hsa_gb)별로 산출 (PDF의 "권역별 중증응급환자 대구광역시 유출 현황"과 동일 구도) */
proc format;
value hsafmt
1='안동권' 2='경주권' 3='포항권' 4='구미권' 5='영주권' 6='상주권';
run;

data work.severe_daegu_top;
set save.pa_area end=eof;
if emergency_dis=1;
array tot{0:6} _temporary_ (7*0);   *0=전체, 1~6=진료권;
array outn{0:6} _temporary_ (7*0);
array topn{0:6} _temporary_ (7*0);
tot{0}+1;
if gb_sido_out=0 then outn{0}+1;
if gb_dg_topgo=1 then topn{0}+1;
if 1<=pa_hsa_gb<=6 then do;
  tot{pa_hsa_gb}+1;
  if gb_sido_out=0 then outn{pa_hsa_gb}+1;
  if gb_dg_topgo=1 then topn{pa_hsa_gb}+1;
end;
if eof then do g=0 to 6;
  group = ifc(g=0,'전체(경북)',put(g,hsafmt.));
  total_n=tot{g};
  out_n=outn{g};
  top6_n=topn{g};
  top6_pct_of_out = ifn(out_n>0, round(top6_n/out_n*100,0.1), .);
  output;
end;
keep group total_n out_n top6_n top6_pct_of_out;
run;

proc print data=work.severe_daegu_top noobs label;
label group='구분' total_n='전체 중증응급환자수' out_n='유출 건수'
      top6_n='대구 종합병원급이상(6개병원) 유출 건수'
      top6_pct_of_out='유출건수 대비 대구 종합병원급이상 유출률(%)';
run;
