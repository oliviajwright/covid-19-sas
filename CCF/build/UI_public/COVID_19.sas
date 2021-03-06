/* SAS Program COVID_19 
Cleveland Clinic and SAS Collaboarion

These models are only as good as their inputs. 
Input values for this type of model are very dynamic and may need to be evaluated across wide ranges and reevaluated as the epidemic progresses.  
This work is currently defaulting to values for the population studied in the Cleveland Clinic and SAS collaboration.
You need to evaluate each parameter for your population of interest.
*/



/* Depending on which SAS products you have and which releases you have these options will turn components of this code on/off */
    %LET HAVE_SASETS = YES; /* YES implies you have SAS/ETS software, this enable the PROC MODEL methods in this code.  Without this the Data Step SIR model still runs */
    %LET HAVE_V151 = NO; /* YES implies you have products verison 15.1 (latest) and switches PROC MODEL to PROC TMODEL for faster execution */

/* User Interface Switches - these are used if you using the code within SAS Visual Analytics UI */
    %LET ScenarioSource = UI;
    %LET CASSource = casuser; 
    /* NOTES: 
        - &ScenarioSource = UI overrides the behavior of the %EasyRun macro
        - &CASSource is the location of the results tables you want the macro to read from in determining if a scenario has been run before: can be a libname or caslib
        - An active CAS session and CASLIB are needed for &CASSource to be available to the %EasyRun macro if you set &CASSource to a caslib
        - At the end of execution all the output tables holding just the current scenario will be in WORK
        - If &ScenarioExist = 0 then the files in WORK contain a new scenario
            - Else, %ScenarioExist > 0, the files in WORK contain a recalled, previously run scenario identified by the columns ScenarioIndex, ScenarioSource, ScenarioUser, ScenarionNameUnique
                - The column Scenario will contain the name entered in the UI as the name is not used in matching previous scenarios
                - these global macro variables will have recalled scenario information in this case (empty when &ScenarioExist=0): &ScenerioIndex_Recall, &ScenarioUser_Recall, &Scenario_Source_Recall, &ScenarioNameUnique_Recall
        - The code assumes that the files it is creating are not in the current SAS workspace.  If there are files with the same name then unexpected behavior will cause issues: appending new data to existing data without warning.
    */

%macro EasyRun(Scenario,IncubationPeriod,InitRecovered,RecoveryDays,doublingtime,Population,KnownAdmits,
                SocialDistancing,ISOChangeDate,ISOChangeEvent,SocialDistancingChange,
                MarketSharePercent,Admission_Rate,ICUPercent,VentPErcent,FatalityRate,
                plots=no,N_DAYS=365,DiagnosedRate=1.0,E=0,SIGMA=3,DAY_ZERO='13MAR2020'd,BETA_DECAY=0.0,
                ECMO_RATE=0.03,DIAL_RATE=0.05,HOSP_LOS=7,ICU_LOS=9,VENT_LOS=10,ECMO_LOS=6,DIAL_LOS=11);

    DATA INPUTS;
        FORMAT
            Scenario                    $200.     
            IncubationPeriod            BEST12.    
            InitRecovered               BEST12.  
            RecoveryDays                BEST12.    
            doublingtime                BEST12.    
            Population                  BEST12.    
            KnownAdmits                 BEST12.    
            SocialDistancing            BEST12.    
            ISOChangeDate               $200.    
            ISOChangeEvent              $200.
            SocialDistancingChange      $50.     
            MarketSharePercent          BEST12.    
            Admission_Rate              BEST12.    
            ICUPercent                  BEST12.    
            VentPErcent                 BEST12.    
            FatalityRate                BEST12.   
            plots                       $3.
            N_DAYS                      BEST12.
            DiagnosedRate               BEST12.
            E                           BEST12.
            SIGMA                       BEST12.
            DAY_ZERO                    DATE9.
            BETA_DECAY                  BEST12.
            ECMO_RATE                   BEST12.
            DIAL_RATE                   BEST12.
            HOSP_LOS                    BEST12.
            ICU_LOS                     BEST12.
            VENT_LOS                    BEST12.
            ECMO_LOS                    BEST12.
            DIAL_LOS                    BEST12.
        ;
        LABEL
            Scenario                    =   "Scenario Name"
            IncubationPeriod            =   "Average Days between Infection and Hospitalization"
            InitRecovered               =   "Number of Recovered (Immune) Patients on Day 0"
            RecoveryDays                =   "Average Days Infectious"
            doublingtime                =   "Baseline Infection Doubling Time (No Social Distancing)"
            Population                  =   "Regional Population"
            KnownAdmits                 =   "Number of Admitted Patients in Hospital of Interest on Day 0"
            SocialDistancing            =   "Initial Social Distancing (% Reduction from Normal)"
            ISOChangeDate               =   "Dates of Change in Social Distancing"
            ISOChangeEvent              =   "Event label associated with ISOChangeDate"
            SocialDistancingChange      =   "Social Distancing Change (% Reduction from Normal)"
            MarketSharePercent          =   "Anticipated Share (%) of Regional Hospitalized Patients"
            Admission_Rate              =   "Percentage of Infected Patients Requiring Hospitalization"
            ICUPercent                  =   "Percentage of Hospitalized Patients Requiring ICU"
            VentPErcent                 =   "Percentage of Hospitalized Patients Requiring Ventilators"
            FatalityRate                =   "Percentage of Hospitalized Patients who will Die"
            plots                       =   "Display Plots (Yes/No)"
            N_DAYS                      =   "Number of Days to Project"
            DiagnosedRate               =   "Hospitalization Rate Reduction (%) for Underdiagnosis"
            E                           =   "Number of Exposed Patients on Day 0"
            SIGMA                       =   "Days Exposed before Infected"
            DAY_ZERO                    =   "Date of the First COVID-19 Case"
            BETA_DECAY                  =   "Daily Reduction (%) of Beta"
            ECMO_RATE                   =   "Percentage of Hospitalized Patients Requiring ECMO"
            DIAL_RATE                   =   "Percentage of Hospitalized Patients Requiring Dialysis"
            HOSP_LOS                    =   "Average Hospital Length of Stay"
            ICU_LOS                     =   "Average ICU Length of Stay"
            VENT_LOS                    =   "Average Ventilator Length of Stay"
            ECMO_LOS                    =   "Average ECMO Length of Stay"
            DIAL_LOS                    =   "Average Dialysis Length of Stay"
        ;
        Scenario                    =   "&Scenario.";
        IncubationPeriod            =   &IncubationPeriod.;
        InitRecovered               =   &InitRecovered.;
        RecoveryDays                =   &RecoveryDays.;
        doublingtime                =   &doublingtime.;
        Population                  =   &Population.;
        KnownAdmits                 =   &KnownAdmits.;
        SocialDistancing            =   &SocialDistancing.;
        ISOChangeDate               =   "&ISOChangeDate.";
        ISOChangeEvent              =   "&ISOChangeEvent.";
        SocialDistancingChange      =   "&SocialDistancingChange.";
        MarketSharePercent          =   &MarketSharePercent.;
        Admission_Rate              =   &Admission_Rate.;
        ICUPercent                  =   &ICUPercent.;
        VentPErcent                 =   &VentPErcent.;
        FatalityRate                =   &FatalityRate.;
        plots                       =   "&plots.";
        N_DAYS                      =   &N_DAYS.;
        DiagnosedRate               =   &DiagnosedRate.;
        E                           =   &E.;
        SIGMA                       =   &SIGMA.;
        DAY_ZERO                    =   &DAY_ZERO.;
        BETA_DECAY                  =   &BETA_DECAY.;
        ECMO_RATE                   =   &ECMO_RATE.;
        DIAL_RATE                   =   &DIAL_RATE.;
        HOSP_LOS                    =   &HOSP_LOS.;
        ICU_LOS                     =   &ICU_LOS.;
        VENT_LOS                    =   &VENT_LOS.;
        ECMO_LOS                    =   &ECMO_LOS.;
        DIAL_LOS                    =   &DIAL_LOS.;
    RUN;

    %IF &ScenarioSource = UI %THEN %DO;
        /* this session is only used for reading the SCENARIOS table in the global caslib when the UI is running the scenario */
        %LET PULLLIB=&CASSource.;
    %END;
    %ELSE %DO;
        %LET PULLLIB=store;
    %END;

    /* create an index, ScenarioIndex for this run by incrementing the max value of ScenarioIndex in SCENARIOS dataset */
        %IF %SYSFUNC(exist(&PULLLIB..scenarios)) %THEN %DO;
            PROC SQL noprint; select max(ScenarioIndex) into :ScenarioIndex_Base from &PULLLIB..scenarios where ScenarioSource="&ScenarioSource."; quit;
            /* this may be the first ScenarioIndex for the ScenarioSource - catch and set to 0 */
            %IF &ScenarioIndex_Base = . %THEN %DO; %LET ScenarioIndex_Base = 0; %END;
        %END;
        %ELSE %DO; %LET ScenarioIndex_Base = 0; %END;
        %LET ScenarioIndex = %EVAL(&ScenarioIndex_Base + 1);

    /* store all the macro variables that set up this scenario in SCENARIOS dataset */
        DATA SCENARIOS;
            set sashelp.vmacro(where=(scope='EASYRUN'));
            if name in ('SQLEXITCODE','SQLOBS','SQLOOPS','SQLRC','SQLXOBS','SQLXOPENERRS','SCENARIOINDEX_BASE','PULLLIB') then delete;
				FORMAT ScenarioName $50. ScenarioNameUnique $100. ScenarioSource $10. ScenarioUser $25.;
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
            STAGE='INPUT';
        RUN;
        DATA INPUTS; 
            set INPUTS;
				FORMAT ScenarioName $50. ScenarioNameUnique $100. ScenarioSource $10. ScenarioUser $25.;
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
            label ScenarioIndex="Unique Scenario ID";
        RUN;

        /* Calculate Parameters form Macro Inputs Here - these are repeated as comments at the start of each model phase below */
			* calculated parameters used in model post-processing;
				%LET HOSP_RATE = %SYSEVALF(&Admission_Rate. * &DiagnosedRate.);
				%LET ICU_RATE = %SYSEVALF(&ICUPercent. * &DiagnosedRate.);
				%LET VENT_RATE = %SYSEVALF(&VentPErcent. * &DiagnosedRate.);
			* calculated parameters used in models;
				%LET I = %SYSEVALF(&KnownAdmits. / 
											&MarketSharePercent. / 
												(&Admission_Rate. * &DiagnosedRate.));
				%LET GAMMA = %SYSEVALF(1 / &RecoveryDays.);
				%IF &SIGMA. <= 0 %THEN %LET SIGMA = 0.00000001;
					%LET SIGMAINV = %SYSEVALF(1 / &SIGMA.);
				%LET BETA = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancing.));
				%LET R_T = %SYSEVALF(&BETA. / &GAMMA. * &Population.);

				%IF %sysevalf(%superq(SocialDistancingChange)=,boolean)=0 %THEN %DO;
					%LET sdchangetitle=Adjust R0 (Date / Event / R0 / Social Distancing):;
					%DO j = 1 %TO %SYSFUNC(countw(&SocialDistancingChange.,:));
						%LET SocialDistancingChange&j = %scan(&SocialDistancingChange.,&j,:);
						%LET BETAChange&j = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &&SocialDistancingChange&j));
						%LET R_T_Change&j = %SYSEVALF(&&BETAChange&j / &GAMMA. * &Population.);
						%LET ISOChangeDate&j = %scan(&ISOChangeDate.,&j,:);
						%LET ISOChangeEvent&j = %scan(&ISOChangeEvent.,&j,:);
						%LET sdchangetitle = &sdchangetitle. (%sysfunc(INPUTN(&&ISOChangeDate&j., date10.), date9.) / &&ISOChangeEvent&j / %SYSFUNC(round(&&R_T_Change&j,.01)) / %SYSEVALF(&&SocialDistancingChange&j.*100)%);
					%END; 
				%END;
				%ELSE %DO;
					%LET sdchangetitle=No Adjustment to R0 over time;
				%END;
				
        DATA SCENARIOS;
            set SCENARIOS sashelp.vmacro(in=i where=(scope='EASYRUN'));
            if name in ('SQLEXITCODE','SQLOBS','SQLOOPS','SQLRC','SQLXOBS','SQLXOPENERRS','SCENARIOINDEX_BASE','PULLLIB','SDCHANGETITLE','J') then delete;
				FORMAT ScenarioName $50. ScenarioNameUnique $100. ScenarioSource $10. ScenarioUser $25.;
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
            if i then STAGE='MODEL';
        RUN;
    /* Check to see if SCENARIOS (this scenario) has already been run before in SCENARIOS dataset */
        %GLOBAL ScenarioExist;
        %IF %SYSFUNC(exist(&PULLLIB..scenarios)) %THEN %DO;
            PROC SQL noprint;
                /* has this scenario been run before - all the same parameters and value - no more and no less */
                select count(*) into :ScenarioExist from
                    (select t1.ScenarioIndex, t2.ScenarioIndex, t2.ScenarioSource, t2.ScenarioUser
                        from 
                            (select *, count(*) as cnt 
                                from work.SCENARIOS
                                where name not in ('SCENARIO','SCENARIOINDEX_BASE','SCENARIONAMEUNIQUE','SCENARIOINDEX','SCENARIOSOURCE','SCENARIOUSER','SCENPLOT','PLOTS')
                                group by ScenarioIndex, ScenarioSource, ScenarioUser) t1
                            join
                            (select * from &PULLLIB..SCENARIOS
                                where name not in ('SCENARIO','SCENARIOINDEX_BASE','SCENARIONAMEUNIQUE','SCENARIOINDEX','SCENARIOSOURCE','SCENARIOUSER','SCENPLOT','PLOTS')) t2
                            on t1.name=t2.name and t1.value=t2.value and t1.STAGE=t2.STAGE
                        group by t1.ScenarioIndex, t2.ScenarioIndex, t2.ScenarioSource, t2.ScenarioUser, t1.cnt
                        having count(*) = t1.cnt)
                ; 
            QUIT;
        %END; 
        %ELSE %DO; 
            %LET ScenarioExist = 0;
        %END;

    /* recall an existing scenario to SASWORK if it matched */
        %GLOBAL ScenarioIndex_recall ScenarioSource_recall ScenarioUser_recall ScenarioNameUnique_recall ScenarioName_recall;
        %IF &ScenarioExist = 0 %THEN %DO;
            PROC SQL noprint; select max(ScenarioIndex) into :ScenarioIndex from work.SCENARIOS; QUIT;
        %END;
        /*%ELSE %IF &PLOTS. = YES %THEN %DO;*/
        %ELSE %DO;
            /* what was a ScenarioIndex value that matched the requested scenario - store that in ScenarioIndex_recall ... */
            PROC SQL noprint; /* can this be combined with the similar code above that counts matching scenarios? */
				select t2.ScenarioIndex, t2.ScenarioSource, t2.ScenarioUser, t2.ScenarioNameUnique, t2.ScenarioName into :ScenarioIndex_recall, :ScenarioSource_recall, :ScenarioUser_recall, :ScenarioNameUnique_recall, :ScenarioName_recall from
                    (select t1.ScenarioIndex, t2.ScenarioIndex, t2.ScenarioSource, t2.ScenarioUser, t2.ScenarioNameUnique, t2.ScenarioName
                        from 
                            (select *, count(*) as cnt 
                                from work.SCENARIOS
                                where name not in ('SCENARIO','SCENARIOINDEX_BASE','SCENARIONAMEUNIQUE','SCENARIOINDEX','SCENARIOSOURCE','SCENARIOUSER','SCENPLOT','PLOTS')
                                group by ScenarioIndex) t1
                            join
                            (select * from &PULLLIB..SCENARIOS
                                where name not in ('SCENARIO','SCENARIOINDEX_BASE','SCENARIONAMEUNIQUE','SCENARIOINDEX','SCENARIOSOURCE','SCENARIOUSER','SCENPLOT','PLOTS')) t2
                            on t1.name=t2.name and t1.value=t2.value and t1.STAGE=t2.STAGE
                        group by t1.ScenarioIndex, t2.ScenarioIndex, t2.ScenarioSource, t2.ScenarioUser, t1.cnt
                        having count(*) = t1.cnt)
                ;
            QUIT;
            /* pull the current scenario data to work for plots below */
            data work.MODEL_FINAL; set &PULLLIB..MODEL_FINAL; where ScenarioIndex=&ScenarioIndex_recall. and ScenarioSource="&ScenarioSource_recall." and ScenarioUser="&ScenarioUser_recall."; run;

            %LET ScenarioIndex = &ScenarioIndex_recall.;
        %END;

    /* Prepare to create request plots from input parameter plots= */
        %IF %UPCASE(&plots.) = YES %THEN %DO; %LET plots = YES; %END;
        %ELSE %DO; %LET plots = NO; %END;

	/*PROC TMODEL SEIR APPROACH*/
		/* these are the calculations for variables used from above:
			* calculated parameters used in model post-processing;
				%LET HOSP_RATE = %SYSEVALF(&Admission_Rate. * &DiagnosedRate.);
				%LET ICU_RATE = %SYSEVALF(&ICUPercent. * &DiagnosedRate.);
				%LET VENT_RATE = %SYSEVALF(&VentPErcent. * &DiagnosedRate.);
			* calculated parameters used in models;
				%LET I = %SYSEVALF(&KnownAdmits. / 
											&MarketSharePercent. / 
												(&Admission_Rate. * &DiagnosedRate.));
				%LET GAMMA = %SYSEVALF(1 / &RecoveryDays.);
				%IF &SIGMA. <= 0 %THEN %LET SIGMA = 0.00000001;
					%LET SIGMAINV = %SYSEVALF(1 / &SIGMA.);
				%LET BETA = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancing.));
				%LET R_T = %SYSEVALF(&BETA. / &GAMMA. * &Population.);

				%IF %sysevalf(%superq(SocialDistancingChange)=,boolean)=0 %THEN %DO;
					%LET sdchangetitle=Adjust R0 (Date / Event / R0 / Social Distancing):;
					%DO j = 1 %TO %SYSFUNC(countw(&SocialDistancingChange.,:));
						%LET SocialDistancingChange&j = %scan(&SocialDistancingChange.,&j,:);
						%LET BETAChange&j = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &&SocialDistancingChange&j));
						%LET R_T_Change&j = %SYSEVALF(&&BETAChange&j / &GAMMA. * &Population.);
						%LET ISOChangeDate&j = %scan(&ISOChangeDate.,&j,:);
						%LET ISOChangeEvent&j = %scan(&ISOChangeEvent.,&j,:);
						%LET sdchangetitle = &sdchangetitle. (%sysfunc(INPUTN(&&ISOChangeDate&j., date10.), date9.) / &&ISOChangeEvent&j / %SYSFUNC(round(&&R_T_Change&j,.01)) / %SYSEVALF(&&SocialDistancingChange&j.*100)%);
					%END; 
				%END;
				%ELSE %DO;
					%LET sdchangetitle=No Adjustment to R0 over time;
				%END;
						*/
		/* If this is a new scenario then run it */
    	%IF &ScenarioExist = 0 AND &HAVE_SASETS = YES %THEN %DO;
			/*DATA FOR PROC TMODEL APPROACHES*/
				DATA DINIT(Label="Initial Conditions of Simulation");  
                    S_N = &Population. - (&I. / &DiagnosedRate.) - &InitRecovered.;
                    E_N = &E.;
                    I_N = &I. / &DiagnosedRate.;
                    R_N = &InitRecovered.;
                    *R0  = &R_T.;
                    /* prevent range below zero on each loop */
                    DO SIGMAfraction = 0.8 TO 1.2 BY 0.1;
					SIGMAINV = 1/(SIGMAfraction*&SIGMA.);
					SIGMAfraction = round(SIGMAfraction,.00001);
					DO RECOVERYDAYSfraction = 0.8 TO 1.2 BY 0.1;
                    RECOVERYDAYS = RECOVERYDAYSfraction * &RecoveryDays;
					RECOVERYDAYSfraction = round(RECOVERYDAYSfraction,.00001);
                        DO SOCIALDfraction = -.2 TO .2 BY 0.1;
						SOCIALD = SOCIALDfraction + &SocialDistancing;
						SOCIALDfraction = round(SOCIALDfraction,.00001);
						IF SOCIALD >=0 and SOCIALD<=1 THEN DO; 
                                GAMMA = 1 / RECOVERYDAYS;
                                BETA = ((2 ** (1 / &doublingtime.) - 1) + GAMMA) / 
                                                &Population. * (1 - SOCIALD);
								R_T = BETA / GAMMA * &Population.;
								%DO j = 1 %TO %SYSFUNC(countw(&SocialDistancingChange.,:));
									BETAChange&j = ((2 ** (1 / &doublingtime.) - 1) + GAMMA) / 
													&Population. * (1 - &&SocialDistancingChange&j);
									R_T_Change&j = BETAChange&j / GAMMA * &Population.;
								%END;
                                DO TIME = 0 TO &N_DAYS. by 1;
                                    OUTPUT; 
                                END;
                            END;
                        END;
						END;
					END; 
				RUN;

			%IF &HAVE_V151 = YES %THEN %DO; PROC TMODEL DATA = DINIT NOPRINT; performance nthreads=4 bypriority=1 partpriority=1; %END;
			%ELSE %DO; PROC MODEL DATA = DINIT NOPRINT; %END;
				/* PARAMETER SETTINGS */ 
                PARMS N &Population.;
                BOUNDS 1 <= R_T <= 13;
				%LET jmax = %SYSFUNC(countw(&SocialDistancingChange.,:));
				RESTRICT R_T > 0 %DO j = 1 %TO &jmax; , R_T_Change&j > 0 %END;;
				%IF &jmax = 0 %THEN %DO; BETA = BETA; %END;
				%ELSE %DO;
					%DO j = 1 %TO &jmax;
						%LET j2 = %eval(&j + 1);
						%IF &j = 1 %THEN %DO; 
							change_0 = (TIME < (&&ISOChangeDate&j - &DAY_ZERO));
						%END;
						%IF &j = &jmax %THEN %DO;
							change_&j = (TIME >= (&&ISOChangeDate&j - &DAY_ZERO));
						%END;
						%ELSE %DO;
							change_&j = ((TIME >= (&&ISOChangeDate&j - &DAY_ZERO.)) & (TIME < (&&ISOChangeDate&j2 - &DAY_ZERO.)));
						%END;
					%END;
					BETA = change_0*R_T*GAMMA/N %DO j = 1 %TO &jmax; + change_&j*R_T_Change&j*GAMMA/N %END;; 
				%END;
				/* DIFFERENTIAL EQUATIONS */ 
				/* a. Decrease in healthy susceptible persons through infections: number of encounters of (S,I)*TransmissionProb*/
				DERT.S_N = -BETA*S_N*I_N;
				/* b. inflow from a. -Decrease in Exposed: alpha*e "promotion" inflow from E->I;*/
				DERT.E_N = BETA*S_N*I_N - SIGMAINV*E_N;
				/* c. inflow from b. - outflow through recovery or death during illness*/
				DERT.I_N = SIGMAINV*E_N - GAMMA*I_N;
				/* d. Recovered and death humans through "promotion" inflow from c.*/
				DERT.R_N = GAMMA*I_N;           
				/* SOLVE THE EQUATIONS */ 
				SOLVE S_N E_N I_N R_N / TIME=TIME OUT = TMODEL_SEIR_SIM; 
                by SIGMAfraction RECOVERYDAYSfraction SOCIALDfraction;
			RUN;
			QUIT;

			/* use the center point of the ranges for the requested scenario inputs */
			DATA TMODEL_SEIR;
				FORMAT ModelType $30. DATE ADMIT_DATE DATE9.;
				ModelType="SEIR with PROC (T)MODEL";
				FORMAT ScenarioName $50. ScenarioNameUnique $100. ScenarioSource $10. ScenarioUser $25.;
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
				RETAIN LAG_S LAG_E LAG_I LAG_R LAG_N CUMULATIVE_SUM_HOSP CUMULATIVE_SUM_ICU CUMULATIVE_SUM_VENT CUMULATIVE_SUM_ECMO CUMULATIVE_SUM_DIAL Cumulative_sum_fatality
					CUMULATIVE_SUM_MARKET_HOSP CUMULATIVE_SUM_MARKET_ICU CUMULATIVE_SUM_MARKET_VENT CUMULATIVE_SUM_MARKET_ECMO CUMULATIVE_SUM_MARKET_DIAL cumulative_Sum_Market_Fatality;
				LAG_S = S_N; 
				LAG_E = E_N; 
				LAG_I = I_N; 
				LAG_R = R_N; 
				LAG_N = N; 
				SET TMODEL_SEIR_SIM(RENAME=(TIME=DAY) DROP=_ERRORS_ _MODE_ _TYPE_);
                WHERE SIGMAfraction=1 and RECOVERYDAYSfraction=1 and SOCIALDfraction=0;
				N = SUM(S_N, E_N, I_N, R_N);
				SCALE = LAG_N / N;
				/* START: Common Post-Processing Across each Model Type and Approach */
					NEWINFECTED=LAG&IncubationPeriod(SUM(LAG(SUM(S_N,E_N)),-1*SUM(S_N,E_N)));
					IF NEWINFECTED < 0 THEN NEWINFECTED=0;
					HOSP = NEWINFECTED * &HOSP_RATE. * &MarketSharePercent.;
					ICU = NEWINFECTED * &ICU_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					VENT = NEWINFECTED * &VENT_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					ECMO = NEWINFECTED * &ECMO_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					DIAL = NEWINFECTED * &DIAL_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					Fatality = NEWINFECTED * &FatalityRate * &MarketSharePercent. * &HOSP_RATE.;
					MARKET_HOSP = NEWINFECTED * &HOSP_RATE.;
					MARKET_ICU = NEWINFECTED * &ICU_RATE. * &HOSP_RATE.;
					MARKET_VENT = NEWINFECTED * &VENT_RATE. * &HOSP_RATE.;
					MARKET_ECMO = NEWINFECTED * &ECMO_RATE. * &HOSP_RATE.;
					MARKET_DIAL = NEWINFECTED * &DIAL_RATE. * &HOSP_RATE.;
					Market_Fatality = NEWINFECTED * &FatalityRate. * &HOSP_RATE.;
					CUMULATIVE_SUM_HOSP + HOSP;
					CUMULATIVE_SUM_ICU + ICU;
					CUMULATIVE_SUM_VENT + VENT;
					CUMULATIVE_SUM_ECMO + ECMO;
					CUMULATIVE_SUM_DIAL + DIAL;
					Cumulative_sum_fatality + Fatality;
					CUMULATIVE_SUM_MARKET_HOSP + MARKET_HOSP;
					CUMULATIVE_SUM_MARKET_ICU + MARKET_ICU;
					CUMULATIVE_SUM_MARKET_VENT + MARKET_VENT;
					CUMULATIVE_SUM_MARKET_ECMO + MARKET_ECMO;
					CUMULATIVE_SUM_MARKET_DIAL + MARKET_DIAL;
					cumulative_Sum_Market_Fatality + Market_Fatality;
					CUMADMITLAGGED=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_HOSP),1) ;
					CUMICULAGGED=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_ICU),1) ;
					CUMVENTLAGGED=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_VENT),1) ;
					CUMECMOLAGGED=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_ECMO),1) ;
					CUMDIALLAGGED=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_DIAL),1) ;
					CUMMARKETADMITLAG=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_MARKET_HOSP));
					CUMMARKETICULAG=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_MARKET_ICU));
					CUMMARKETVENTLAG=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_MARKET_VENT));
					CUMMARKETECMOLAG=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_MARKET_ECMO));
					CUMMARKETDIALLAG=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_MARKET_DIAL));
					ARRAY FIXINGDOT _NUMERIC_;
					DO OVER FIXINGDOT;
						IF FIXINGDOT=. THEN FIXINGDOT=0;
					END;
					HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_HOSP-CUMADMITLAGGED,1);
					ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_ICU-CUMICULAGGED,1);
					VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_VENT-CUMVENTLAGGED,1);
					ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_ECMO-CUMECMOLAGGED,1);
					DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_DIAL-CUMDIALLAGGED,1);
					Deceased_Today = Fatality;
					Total_Deaths = Cumulative_sum_fatality;
					MedSurgOccupancy=Hospital_Occupancy-ICU_Occupancy;
					MARKET_HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_HOSP-CUMMARKETADMITLAG,1);
					MARKET_ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_ICU-CUMMARKETICULAG,1);
					MARKET_VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_VENT-CUMMARKETVENTLAG,1);
					MARKET_ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_ECMO-CUMMARKETECMOLAG,1);
					MARKET_DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_DIAL-CUMMARKETDIALLAG,1);	
					Market_Deceased_Today = Market_Fatality;
					Market_Total_Deaths = cumulative_Sum_Market_Fatality;
					Market_MEdSurg_Occupancy=Market_Hospital_Occupancy-MArket_ICU_Occupancy;
					DATE = &DAY_ZERO. + round(DAY,1);
					ADMIT_DATE = SUM(DATE, &IncubationPeriod.);
					FORMAT ISOChangeEvent $30.;
					%IF %sysevalf(%superq(ISOChangeDate)=,boolean)=0 %THEN %DO;
						%DO j = 1 %TO %SYSFUNC(countw(&ISOChangeDate.,:)); 
							IF DATE = &&ISOChangeDate&j THEN DO;
								ISOChangeEvent = "&&ISOChangeEvent&j";
								/* the values in EventY_Multiplier will get multiplied by Peak values later in the code */
								EventY_Multiplier = 1.1+MOD(&j,2)/10;
							END;
						%END;
					%END;
					%ELSE %DO;
						ISOChangeEvent = '';
						EventY_Multiplier = .;
					%END;
				/* END: Common Post-Processing Across each Model Type and Approach */
				DROP LAG: CUM: SIGMAINV SIGMAfraction RECOVERYDAYS RECOVERYDAYSfraction SOCIALD SOCIALDfraction BETA GAMMA R_T:;
			RUN;

            /* round time to integers - precision */
            proc sql;
                create table TMODEL_SEIR_SIM as
                    select sum(S_N,E_N) as SE, SIGMAfraction, RECOVERYDAYSfraction, SOCIALDfraction, round(Time,1) as Time
                    from TMODEL_SEIR_SIM
                    order by SIGMAfraction, RECOVERYDAYSfraction, SOCIALDfraction, Time
                ;
            quit;

            /* use a skeleton from the normal post-processing to processes every scenario.
                by statement used for separating scenarios - order by in sql above prepares this
                note that lag function used in conditional logic can be very tricky.
                The code below has logic to override the lag at the start of each by group.
            */
			DATA TMODEL_SEIR_SIM;
				FORMAT ModelType $30. DATE date9.;
				ModelType="SEIR with PROC (T)MODEL";
				FORMAT ScenarioName $50. ScenarioNameUnique $100. ScenarioSource $10. ScenarioUser $25.;
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
				RETAIN counter CUMULATIVE_SUM_HOSP CUMULATIVE_SUM_ICU CUMULATIVE_SUM_VENT CUMULATIVE_SUM_ECMO CUMULATIVE_SUM_DIAL;
				SET TMODEL_SEIR_SIM(RENAME=(TIME=DAY));
                by SIGMAfraction RECOVERYDAYSfraction SOCIALDfraction;
                    if first.SOCIALD then do;
                        counter = 1;
                        CUMULATIVE_SUM_HOSP=0;
                        CUMULATIVE_SUM_ICU=0;
                        CUMULATIVE_SUM_VENT=0;
                        CUMULATIVE_SUM_ECMO=0;
                        CUMULATIVE_SUM_DIAL=0;
                    end;
                    else do;
                        counter+1;
                    end;
				/* START: Common Post-Processing Across each Model Type and Approach */
					NEWINFECTED=LAG&IncubationPeriod(SUM(LAG(SE),-1*SE));
                        if counter<&IncubationPeriod then NEWINFECTED=.; /* reset the lag for by group */

					IF NEWINFECTED < 0 THEN NEWINFECTED=0;
					HOSP = NEWINFECTED * &HOSP_RATE. * &MarketSharePercent.;
					ICU = NEWINFECTED * &ICU_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					VENT = NEWINFECTED * &VENT_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					ECMO = NEWINFECTED * &ECMO_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					DIAL = NEWINFECTED * &DIAL_RATE. * &MarketSharePercent. * &HOSP_RATE.;

					CUMULATIVE_SUM_HOSP + HOSP;
					CUMULATIVE_SUM_ICU + ICU;
					CUMULATIVE_SUM_VENT + VENT;
					CUMULATIVE_SUM_ECMO + ECMO;
					CUMULATIVE_SUM_DIAL + DIAL;

                    CUMADMITLAGGED=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_HOSP),1) ;
                        if counter<=&HOSP_LOS then CUMADMITLAGGED=.; /* reset the lag for by group */
					CUMICULAGGED=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_ICU),1) ;
                        if counter<=&ICU_LOS then CUMICULAGGED=.; /* reset the lag for by group */
					CUMVENTLAGGED=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_VENT),1) ;
                        if counter<=&VENT_LOS then CUMVENTLAGGED=.; /* reset the lag for by group */
					CUMECMOLAGGED=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_ECMO),1) ;
                        if counter<=&ECMO_LOS then CUMECMOLAGGED=.; /* reset the lag for by group */
					CUMDIALLAGGED=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_DIAL),1) ;
                        if counter<=&DIAL_LOS then CUMDIALLAGGED=.; /* reset the lag for by group */

					ARRAY FIXINGDOT _NUMERIC_;
					DO OVER FIXINGDOT;
						IF FIXINGDOT=. THEN FIXINGDOT=0;
					END;
					
                    HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_HOSP-CUMADMITLAGGED,1);
					ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_ICU-CUMICULAGGED,1);
					VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_VENT-CUMVENTLAGGED,1);
					ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_ECMO-CUMECMOLAGGED,1);
					DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_DIAL-CUMDIALLAGGED,1);
					
					DATE = &DAY_ZERO. + DAY;
				/* END: Common Post-Processing Across each Model Type and Approach */
                KEEP ModelType ScenarioIndex DATE HOSPITAL_OCCUPANCY ICU_OCCUPANCY VENT_OCCUPANCY ECMO_OCCUPANCY DIAL_OCCUPANCY Sigma RECOVERYDAYS SOCIALD;
			RUN;

            PROC SQL noprint;
                create table TMODEL_SEIR as
                    select * from
                        (select * from work.TMODEL_SEIR) B 
                        left join
                        (select min(HOSPITAL_OCCUPANCY) as LOWER_HOSPITAL_OCCUPANCY, 
                                min(ICU_OCCUPANCY) as LOWER_ICU_OCCUPANCY, 
                                min(VENT_OCCUPANCY) as LOWER_VENT_OCCUPANCY, 
                                min(ECMO_OCCUPANCY) as LOWER_ECMO_OCCUPANCY, 
                                min(DIAL_OCCUPANCY) as LOWER_DIAL_OCCUPANCY,
                                max(HOSPITAL_OCCUPANCY) as UPPER_HOSPITAL_OCCUPANCY, 
                                max(ICU_OCCUPANCY) as UPPER_ICU_OCCUPANCY, 
                                max(VENT_OCCUPANCY) as UPPER_VENT_OCCUPANCY, 
                                max(ECMO_OCCUPANCY) as UPPER_ECMO_OCCUPANCY, 
                                max(DIAL_OCCUPANCY) as UPPER_DIAL_OCCUPANCY,
                                Date, ModelType, ScenarioIndex
                            from TMODEL_SEIR_SIM
                            group by Date, ModelType, ScenarioIndex
                        ) U 
                        on B.ModelType=U.ModelType and B.ScenarioIndex=U.ScenarioIndex and B.DATE=U.DATE
                    order by ScenarioIndex, ModelType, Date
                ;
                drop table TMODEL_SEIR_SIM;
            QUIT;

			PROC APPEND base=work.MODEL_FINAL data=TMODEL_SEIR; run;
			PROC SQL; drop table TMODEL_SEIR; drop table DINIT; QUIT;
			
		%END;

		%IF &PLOTS. = YES AND &HAVE_SASETS = YES %THEN %DO;
			PROC SGPLOT DATA=work.MODEL_FINAL;
				where ModelType='SEIR with PROC (T)MODEL' and ScenarioIndex=&ScenarioIndex.;
				TITLE "Daily Occupancy - PROC TMODEL SEIR Approach";
				TITLE2 "Scenario: &Scenario., Initial R0: %SYSFUNC(round(&R_T.,.01)) with Initial Social Distancing of %SYSEVALF(&SocialDistancing.*100)%";
				TITLE3 "&sdchangetitle.";
				SERIES X=DATE Y=HOSPITAL_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=ICU_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=VENT_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=ECMO_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=DIAL_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				XAXIS LABEL="Date";
				YAXIS LABEL="Daily Occupancy";
			RUN;
			TITLE; TITLE2; TITLE3;

			PROC SGPLOT DATA=work.MODEL_FINAL;
				where ModelType='SEIR with PROC (T)MODEL' and ScenarioIndex=&ScenarioIndex.;
				TITLE "Daily Occupancy - PROC TMODEL SEIR Approach With Uncertainty Bounds";
				TITLE2 "Scenario: &Scenario., Initial R0: %SYSFUNC(round(&R_T.,.01)) with Initial Social Distancing of %SYSEVALF(&SocialDistancing.*100)%";
				TITLE3 "&sdchangetitle.";
				
                BAND x=DATE lower=LOWER_HOSPITAL_OCCUPANCY upper=UPPER_HOSPITAL_OCCUPANCY / fillattrs=(color=blue transparency=.8) name="b1";
                BAND x=DATE lower=LOWER_ICU_OCCUPANCY upper=UPPER_ICU_OCCUPANCY / fillattrs=(color=red transparency=.8) name="b2";
                BAND x=DATE lower=LOWER_VENT_OCCUPANCY upper=UPPER_VENT_OCCUPANCY / fillattrs=(color=green transparency=.8) name="b3";
                BAND x=DATE lower=LOWER_ECMO_OCCUPANCY upper=UPPER_ECMO_OCCUPANCY / fillattrs=(color=brown transparency=.8) name="b4";
                BAND x=DATE lower=LOWER_DIAL_OCCUPANCY upper=UPPER_DIAL_OCCUPANCY / fillattrs=(color=purple transparency=.8) name="b5";
                SERIES X=DATE Y=HOSPITAL_OCCUPANCY / LINEATTRS=(color=blue THICKNESS=2) name="l1";
				SERIES X=DATE Y=ICU_OCCUPANCY / LINEATTRS=(color=red THICKNESS=2) name="l2";
				SERIES X=DATE Y=VENT_OCCUPANCY / LINEATTRS=(color=green THICKNESS=2) name="l3";
				SERIES X=DATE Y=ECMO_OCCUPANCY / LINEATTRS=(color=brown THICKNESS=2) name="l4";
				SERIES X=DATE Y=DIAL_OCCUPANCY / LINEATTRS=(color=purple THICKNESS=2) name="l5";
                keylegend "l1" "l2" "l3" "l4" "l5";
                
				XAXIS LABEL="Date";
				YAXIS LABEL="Daily Occupancy";
			RUN;
			TITLE; TITLE2; TITLE3;
		%END;
	/*PROC TMODEL SIR APPROACH*/
		/* these are the calculations for variables used from above:
			* calculated parameters used in model post-processing;
				%LET HOSP_RATE = %SYSEVALF(&Admission_Rate. * &DiagnosedRate.);
				%LET ICU_RATE = %SYSEVALF(&ICUPercent. * &DiagnosedRate.);
				%LET VENT_RATE = %SYSEVALF(&VentPErcent. * &DiagnosedRate.);
			* calculated parameters used in models;
				%LET I = %SYSEVALF(&KnownAdmits. / 
											&MarketSharePercent. / 
												(&Admission_Rate. * &DiagnosedRate.));
				%LET GAMMA = %SYSEVALF(1 / &RecoveryDays.);
				%IF &SIGMA. <= 0 %THEN %LET SIGMA = 0.00000001;
					%LET SIGMAINV = %SYSEVALF(1 / &SIGMA.);
				%LET BETA = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancing.));
				%LET R_T = %SYSEVALF(&BETA. / &GAMMA. * &Population.);

				%IF %sysevalf(%superq(SocialDistancingChange)=,boolean)=0 %THEN %DO;
					%LET sdchangetitle=Adjust R0 (Date / Event / R0 / Social Distancing):;
					%DO j = 1 %TO %SYSFUNC(countw(&SocialDistancingChange.,:));
						%LET SocialDistancingChange&j = %scan(&SocialDistancingChange.,&j,:);
						%LET BETAChange&j = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &&SocialDistancingChange&j));
						%LET R_T_Change&j = %SYSEVALF(&&BETAChange&j / &GAMMA. * &Population.);
						%LET ISOChangeDate&j = %scan(&ISOChangeDate.,&j,:);
						%LET ISOChangeEvent&j = %scan(&ISOChangeEvent.,&j,:);
						%LET sdchangetitle = &sdchangetitle. (%sysfunc(INPUTN(&&ISOChangeDate&j., date10.), date9.) / &&ISOChangeEvent&j / %SYSFUNC(round(&&R_T_Change&j,.01)) / %SYSEVALF(&&SocialDistancingChange&j.*100)%);
					%END; 
				%END;
				%ELSE %DO;
					%LET sdchangetitle=No Adjustment to R0 over time;
				%END;
						*/
		/* If this is a new scenario then run it */
    	%IF &ScenarioExist = 0 AND &HAVE_SASETS = YES %THEN %DO;
			/*DATA FOR PROC TMODEL APPROACHES*/
				DATA DINIT(Label="Initial Conditions of Simulation");  
                    S_N = &Population. - (&I. / &DiagnosedRate.) - &InitRecovered.;
                    E_N = &E.;
                    I_N = &I. / &DiagnosedRate.;
                    R_N = &InitRecovered.;
                    *R0  = &R_T.;
                    /* prevent range below zero on each loop */
                        DO RECOVERYDAYSfraction = 0.8 TO 1.2 BY 0.1;
						RECOVERYDAYS = RECOVERYDAYSfraction*&RecoveryDays;
						RECOVERYDAYSfraction = round(RECOVERYDAYSfraction,.00001);
							DO SOCIALDfraction = -.2 TO .2 BY 0.1;
							SOCIALD = SOCIALDfraction + &SocialDistancing;
							SOCIALDfraction = round(SOCIALDfraction,.00001);
							IF SOCIALD >=0 and SOCIALD<=1 THEN DO; 
                                GAMMA = 1 / RECOVERYDAYS;
                                BETA = ((2 ** (1 / &doublingtime.) - 1) + GAMMA) / 
                                                &Population. * (1 - SOCIALD);
								R_T = BETA / GAMMA * &Population.;
								%DO j = 1 %TO %SYSFUNC(countw(&SocialDistancingChange.,:));
									BETAChange&j = ((2 ** (1 / &doublingtime.) - 1) + GAMMA) / 
													&Population. * (1 - &&SocialDistancingChange&j);
									R_T_Change&j = BETAChange&j / GAMMA * &Population.;
								%END;								
								DO TIME = 0 TO &N_DAYS. by 1;
									OUTPUT; 
								END;
                            END;
							END;
                        END;
				RUN;

			%IF &HAVE_V151 = YES %THEN %DO; PROC TMODEL DATA = DINIT NOPRINT; performance nthreads=4 bypriority=1 partpriority=1; %END;
			%ELSE %DO; PROC MODEL DATA = DINIT NOPRINT; %END;
				/* PARAMETER SETTINGS */ 
                PARMS N &Population.;
                BOUNDS 1 <= R_T <= 13;
				%LET jmax = %SYSFUNC(countw(&SocialDistancingChange.,:));
				RESTRICT R_T > 0 %DO j = 1 %TO &jmax; , R_T_Change&j > 0 %END;;
				%IF &jmax = 0 %THEN %DO; BETA = BETA; %END;
				%ELSE %DO;
					%DO j = 1 %TO &jmax;
						%LET j2 = %eval(&j + 1);
						%IF &j = 1 %THEN %DO; 
							change_0 = (TIME < (&&ISOChangeDate&j - &DAY_ZERO));
						%END;
						%IF &j = &jmax %THEN %DO;
							change_&j = (TIME >= (&&ISOChangeDate&j - &DAY_ZERO));
						%END;
						%ELSE %DO;
							change_&j = ((TIME >= (&&ISOChangeDate&j - &DAY_ZERO.)) & (TIME < (&&ISOChangeDate&j2 - &DAY_ZERO.)));
						%END;
					%END;
					BETA = change_0*R_T*GAMMA/N %DO j = 1 %TO &jmax; + change_&j*R_T_Change&j*GAMMA/N %END;; 
				%END;
				/* DIFFERENTIAL EQUATIONS */ 
				/* a. Decrease in healthy susceptible persons through infections: number of encounters of (S,I)*TransmissionProb*/
				DERT.S_N = -BETA*S_N*I_N;
				/* c. inflow from b. - outflow through recovery or death during illness*/
				DERT.I_N = BETA*S_N*I_N - GAMMA*I_N;
				/* d. Recovered and death humans through "promotion" inflow from c.*/
				DERT.R_N = GAMMA*I_N;           
				/* SOLVE THE EQUATIONS */ 
				SOLVE S_N I_N R_N / TIME=TIME OUT = TMODEL_SIR_SIM; 
                by RECOVERYDAYSfraction SOCIALDfraction;
			RUN;
			QUIT;  

            /* use the center point of the ranges for the requested scenario inputs */
			DATA TMODEL_SIR;
				FORMAT ModelType $30. DATE ADMIT_DATE DATE9.;	
				ModelType="SIR with PROC (T)MODEL";
				FORMAT ScenarioName $50. ScenarioNameUnique $100. ScenarioSource $10. ScenarioUser $25.;
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
				RETAIN LAG_S LAG_I LAG_R LAG_N CUMULATIVE_SUM_HOSP CUMULATIVE_SUM_ICU CUMULATIVE_SUM_VENT CUMULATIVE_SUM_ECMO CUMULATIVE_SUM_DIAL Cumulative_sum_fatality
					CUMULATIVE_SUM_MARKET_HOSP CUMULATIVE_SUM_MARKET_ICU CUMULATIVE_SUM_MARKET_VENT CUMULATIVE_SUM_MARKET_ECMO CUMULATIVE_SUM_MARKET_DIAL cumulative_Sum_Market_Fatality;
				LAG_S = S_N; 
				E_N = &E.; LAG_E = E_N;  /* placeholder for post-processing of SIR model */
				LAG_I = I_N; 
				LAG_R = R_N; 
				LAG_N = N; 
				SET TMODEL_SIR_SIM(RENAME=(TIME=DAY) DROP=_ERRORS_ _MODE_ _TYPE_);
                WHERE RECOVERYDAYSfraction=1 and SOCIALDfraction=0;
				N = SUM(S_N, E_N, I_N, R_N);
				SCALE = LAG_N / N;
				/* START: Common Post-Processing Across each Model Type and Approach */
					NEWINFECTED=LAG&IncubationPeriod(SUM(LAG(SUM(S_N,E_N)),-1*SUM(S_N,E_N)));
					IF NEWINFECTED < 0 THEN NEWINFECTED=0;
					HOSP = NEWINFECTED * &HOSP_RATE. * &MarketSharePercent.;
					ICU = NEWINFECTED * &ICU_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					VENT = NEWINFECTED * &VENT_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					ECMO = NEWINFECTED * &ECMO_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					DIAL = NEWINFECTED * &DIAL_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					Fatality = NEWINFECTED * &FatalityRate * &MarketSharePercent. * &HOSP_RATE.;
					MARKET_HOSP = NEWINFECTED * &HOSP_RATE.;
					MARKET_ICU = NEWINFECTED * &ICU_RATE. * &HOSP_RATE.;
					MARKET_VENT = NEWINFECTED * &VENT_RATE. * &HOSP_RATE.;
					MARKET_ECMO = NEWINFECTED * &ECMO_RATE. * &HOSP_RATE.;
					MARKET_DIAL = NEWINFECTED * &DIAL_RATE. * &HOSP_RATE.;
					Market_Fatality = NEWINFECTED * &FatalityRate. * &HOSP_RATE.;
					CUMULATIVE_SUM_HOSP + HOSP;
					CUMULATIVE_SUM_ICU + ICU;
					CUMULATIVE_SUM_VENT + VENT;
					CUMULATIVE_SUM_ECMO + ECMO;
					CUMULATIVE_SUM_DIAL + DIAL;
					Cumulative_sum_fatality + Fatality;
					CUMULATIVE_SUM_MARKET_HOSP + MARKET_HOSP;
					CUMULATIVE_SUM_MARKET_ICU + MARKET_ICU;
					CUMULATIVE_SUM_MARKET_VENT + MARKET_VENT;
					CUMULATIVE_SUM_MARKET_ECMO + MARKET_ECMO;
					CUMULATIVE_SUM_MARKET_DIAL + MARKET_DIAL;
					cumulative_Sum_Market_Fatality + Market_Fatality;
					CUMADMITLAGGED=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_HOSP),1) ;
					CUMICULAGGED=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_ICU),1) ;
					CUMVENTLAGGED=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_VENT),1) ;
					CUMECMOLAGGED=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_ECMO),1) ;
					CUMDIALLAGGED=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_DIAL),1) ;
					CUMMARKETADMITLAG=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_MARKET_HOSP));
					CUMMARKETICULAG=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_MARKET_ICU));
					CUMMARKETVENTLAG=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_MARKET_VENT));
					CUMMARKETECMOLAG=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_MARKET_ECMO));
					CUMMARKETDIALLAG=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_MARKET_DIAL));
					ARRAY FIXINGDOT _NUMERIC_;
					DO OVER FIXINGDOT;
						IF FIXINGDOT=. THEN FIXINGDOT=0;
					END;
					HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_HOSP-CUMADMITLAGGED,1);
					ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_ICU-CUMICULAGGED,1);
					VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_VENT-CUMVENTLAGGED,1);
					ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_ECMO-CUMECMOLAGGED,1);
					DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_DIAL-CUMDIALLAGGED,1);
					Deceased_Today = Fatality;
					Total_Deaths = Cumulative_sum_fatality;
					MedSurgOccupancy=Hospital_Occupancy-ICU_Occupancy;
					MARKET_HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_HOSP-CUMMARKETADMITLAG,1);
					MARKET_ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_ICU-CUMMARKETICULAG,1);
					MARKET_VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_VENT-CUMMARKETVENTLAG,1);
					MARKET_ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_ECMO-CUMMARKETECMOLAG,1);
					MARKET_DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_DIAL-CUMMARKETDIALLAG,1);	
					Market_Deceased_Today = Market_Fatality;
					Market_Total_Deaths = cumulative_Sum_Market_Fatality;
					Market_MEdSurg_Occupancy=Market_Hospital_Occupancy-MArket_ICU_Occupancy;
					DATE = &DAY_ZERO. + round(DAY,1);
					ADMIT_DATE = SUM(DATE, &IncubationPeriod.);
					FORMAT ISOChangeEvent $30.;
					%IF %sysevalf(%superq(ISOChangeDate)=,boolean)=0 %THEN %DO;
						%DO j = 1 %TO %SYSFUNC(countw(&ISOChangeDate.,:)); 
							IF DATE = &&ISOChangeDate&j THEN DO;
								ISOChangeEvent = "&&ISOChangeEvent&j";
								/* the values in EventY_Multiplier will get multiplied by Peak values later in the code */
								EventY_Multiplier = 1.1+MOD(&j,2)/10;
							END;
						%END;
					%END;
					%ELSE %DO;
						ISOChangeEvent = '';
						EventY_Multiplier = .;
					%END;
				/* END: Common Post-Processing Across each Model Type and Approach */
				DROP LAG: CUM: RECOVERYDAYSfraction RECOVERYDAYS SOCIALDfraction SOCIALD BETA GAMMA R_T:;
			RUN;

            /* round time to integers - precision */
            proc sql;
                create table TMODEL_SIR_SIM as
                    select S_N as SE, RECOVERYDAYSfraction, SOCIALDfraction, round(Time,1) as Time
                    from TMODEL_SIR_SIM
                    order by RECOVERYDAYSfraction, SOCIALDfraction, Time
                ;
            quit; 

            /* use a skeleton from the normal post-processing to processes every scenario.
                by statement used for separating scenarios - order by in sql above prepares this
                note that lag function used in conditional logic can be very tricky.
                The code below has logic to override the lag at the start of each by group.
            */
			DATA TMODEL_SIR_SIM;
				FORMAT ModelType $30. DATE date9.;
				ModelType="SIR with PROC (T)MODEL";
				FORMAT ScenarioName $50. ScenarioNameUnique $100. ScenarioSource $10. ScenarioUser $25.;
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
				RETAIN counter CUMULATIVE_SUM_HOSP CUMULATIVE_SUM_ICU CUMULATIVE_SUM_VENT CUMULATIVE_SUM_ECMO CUMULATIVE_SUM_DIAL;
				SET TMODEL_SIR_SIM(RENAME=(TIME=DAY));
                by RECOVERYDAYSfraction SOCIALDfraction;
                    if first.SOCIALD then do;
                        counter = 1;
                        CUMULATIVE_SUM_HOSP=0;
                        CUMULATIVE_SUM_ICU=0;
                        CUMULATIVE_SUM_VENT=0;
                        CUMULATIVE_SUM_ECMO=0;
                        CUMULATIVE_SUM_DIAL=0;
                    end;
                    else do;
                        counter+1;
                    end;
				/* START: Common Post-Processing Across each Model Type and Approach */
					NEWINFECTED=LAG&IncubationPeriod(SUM(LAG(SE),-1*SE));
                        if counter<&IncubationPeriod then NEWINFECTED=.; /* reset the lag for by group */

					IF NEWINFECTED < 0 THEN NEWINFECTED=0;
					HOSP = NEWINFECTED * &HOSP_RATE. * &MarketSharePercent.;
					ICU = NEWINFECTED * &ICU_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					VENT = NEWINFECTED * &VENT_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					ECMO = NEWINFECTED * &ECMO_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					DIAL = NEWINFECTED * &DIAL_RATE. * &MarketSharePercent. * &HOSP_RATE.;

					CUMULATIVE_SUM_HOSP + HOSP;
					CUMULATIVE_SUM_ICU + ICU;
					CUMULATIVE_SUM_VENT + VENT;
					CUMULATIVE_SUM_ECMO + ECMO;
					CUMULATIVE_SUM_DIAL + DIAL;

                    CUMADMITLAGGED=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_HOSP),1) ;
                        if counter<=&HOSP_LOS then CUMADMITLAGGED=.; /* reset the lag for by group */
					CUMICULAGGED=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_ICU),1) ;
                        if counter<=&ICU_LOS then CUMICULAGGED=.; /* reset the lag for by group */
					CUMVENTLAGGED=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_VENT),1) ;
                        if counter<=&VENT_LOS then CUMVENTLAGGED=.; /* reset the lag for by group */
					CUMECMOLAGGED=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_ECMO),1) ;
                        if counter<=&ECMO_LOS then CUMECMOLAGGED=.; /* reset the lag for by group */
					CUMDIALLAGGED=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_DIAL),1) ;
                        if counter<=&DIAL_LOS then CUMDIALLAGGED=.; /* reset the lag for by group */

					ARRAY FIXINGDOT _NUMERIC_;
					DO OVER FIXINGDOT;
						IF FIXINGDOT=. THEN FIXINGDOT=0;
					END;
					
                    HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_HOSP-CUMADMITLAGGED,1);
					ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_ICU-CUMICULAGGED,1);
					VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_VENT-CUMVENTLAGGED,1);
					ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_ECMO-CUMECMOLAGGED,1);
					DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_DIAL-CUMDIALLAGGED,1);
					
					DATE = &DAY_ZERO. + DAY;
				/* END: Common Post-Processing Across each Model Type and Approach */
                KEEP ModelType ScenarioIndex DATE HOSPITAL_OCCUPANCY ICU_OCCUPANCY VENT_OCCUPANCY ECMO_OCCUPANCY DIAL_OCCUPANCY RECOVERYDAYS SOCIALD;
			RUN;

            PROC SQL noprint;
                create table TMODEL_SIR as
                    select * from
                        (select * from work.TMODEL_SIR) B 
                        left join
                        (select min(HOSPITAL_OCCUPANCY) as LOWER_HOSPITAL_OCCUPANCY, 
                                min(ICU_OCCUPANCY) as LOWER_ICU_OCCUPANCY, 
                                min(VENT_OCCUPANCY) as LOWER_VENT_OCCUPANCY, 
                                min(ECMO_OCCUPANCY) as LOWER_ECMO_OCCUPANCY, 
                                min(DIAL_OCCUPANCY) as LOWER_DIAL_OCCUPANCY,
                                max(HOSPITAL_OCCUPANCY) as UPPER_HOSPITAL_OCCUPANCY, 
                                max(ICU_OCCUPANCY) as UPPER_ICU_OCCUPANCY, 
                                max(VENT_OCCUPANCY) as UPPER_VENT_OCCUPANCY, 
                                max(ECMO_OCCUPANCY) as UPPER_ECMO_OCCUPANCY, 
                                max(DIAL_OCCUPANCY) as UPPER_DIAL_OCCUPANCY,
                                Date, ModelType, ScenarioIndex
                            from TMODEL_SIR_SIM
                            group by Date, ModelType, ScenarioIndex
                        ) U 
                        on B.ModelType=U.ModelType and B.ScenarioIndex=U.ScenarioIndex and B.DATE=U.DATE
                    order by ScenarioIndex, ModelType, Date
                ;
                drop table TMODEL_SIR_SIM;
            QUIT;

			PROC APPEND base=work.MODEL_FINAL data=TMODEL_SIR NOWARN FORCE; run;
			PROC SQL; drop table TMODEL_SIR; drop table DINIT; QUIT;
			
		%END;

		%IF &PLOTS. = YES AND &HAVE_SASETS = YES %THEN %DO;
			PROC SGPLOT DATA=work.MODEL_FINAL;
				where ModelType='SIR with PROC (T)MODEL' and ScenarioIndex=&ScenarioIndex.;
				TITLE "Daily Occupancy - PROC TMODEL SIR Approach";
				TITLE2 "Scenario: &Scenario., Initial R0: %SYSFUNC(round(&R_T.,.01)) with Initial Social Distancing of %SYSEVALF(&SocialDistancing.*100)%";
				TITLE3 "&sdchangetitle.";
				SERIES X=DATE Y=HOSPITAL_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=ICU_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=VENT_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=ECMO_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=DIAL_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				XAXIS LABEL="Date";
				YAXIS LABEL="Daily Occupancy";
			RUN;
			TITLE; TITLE2; TITLE3;

			PROC SGPLOT DATA=work.MODEL_FINAL;
				where ModelType='SIR with PROC (T)MODEL' and ScenarioIndex=&ScenarioIndex.;
				TITLE "Daily Occupancy - PROC TMODEL SIR Approach With Uncertainty Bounds";
				TITLE2 "Scenario: &Scenario., Initial R0: %SYSFUNC(round(&R_T.,.01)) with Initial Social Distancing of %SYSEVALF(&SocialDistancing.*100)%";
				TITLE3 "&sdchangetitle.";
					
                BAND x=DATE lower=LOWER_HOSPITAL_OCCUPANCY upper=UPPER_HOSPITAL_OCCUPANCY / fillattrs=(color=blue transparency=.8) name="b1";
                BAND x=DATE lower=LOWER_ICU_OCCUPANCY upper=UPPER_ICU_OCCUPANCY / fillattrs=(color=red transparency=.8) name="b2";
                BAND x=DATE lower=LOWER_VENT_OCCUPANCY upper=UPPER_VENT_OCCUPANCY / fillattrs=(color=green transparency=.8) name="b3";
                BAND x=DATE lower=LOWER_ECMO_OCCUPANCY upper=UPPER_ECMO_OCCUPANCY / fillattrs=(color=brown transparency=.8) name="b4";
                BAND x=DATE lower=LOWER_DIAL_OCCUPANCY upper=UPPER_DIAL_OCCUPANCY / fillattrs=(color=purple transparency=.8) name="b5";
                SERIES X=DATE Y=HOSPITAL_OCCUPANCY / LINEATTRS=(color=blue THICKNESS=2) name="l1";
				SERIES X=DATE Y=ICU_OCCUPANCY / LINEATTRS=(color=red THICKNESS=2) name="l2";
				SERIES X=DATE Y=VENT_OCCUPANCY / LINEATTRS=(color=green THICKNESS=2) name="l3";
				SERIES X=DATE Y=ECMO_OCCUPANCY / LINEATTRS=(color=brown THICKNESS=2) name="l4";
				SERIES X=DATE Y=DIAL_OCCUPANCY / LINEATTRS=(color=purple THICKNESS=2) name="l5";
                keylegend "l1" "l2" "l3" "l4" "l5";
                
				XAXIS LABEL="Date";
				YAXIS LABEL="Daily Occupancy";
			RUN;
			TITLE; TITLE2; TITLE3;
		%END;
	/* DATA STEP APPROACH FOR SEIR */
		/* these are the calculations for variables used from above:
			* calculated parameters used in model post-processing;
				%LET HOSP_RATE = %SYSEVALF(&Admission_Rate. * &DiagnosedRate.);
				%LET ICU_RATE = %SYSEVALF(&ICUPercent. * &DiagnosedRate.);
				%LET VENT_RATE = %SYSEVALF(&VentPErcent. * &DiagnosedRate.);
			* calculated parameters used in models;
				%LET I = %SYSEVALF(&KnownAdmits. / 
											&MarketSharePercent. / 
												(&Admission_Rate. * &DiagnosedRate.));
				%LET GAMMA = %SYSEVALF(1 / &RecoveryDays.);
				%IF &SIGMA. <= 0 %THEN %LET SIGMA = 0.00000001;
					%LET SIGMAINV = %SYSEVALF(1 / &SIGMA.);
				%LET BETA = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancing.));
				%LET R_T = %SYSEVALF(&BETA. / &GAMMA. * &Population.);

				%IF %sysevalf(%superq(SocialDistancingChange)=,boolean)=0 %THEN %DO;
					%LET sdchangetitle=Adjust R0 (Date / Event / R0 / Social Distancing):;
					%DO j = 1 %TO %SYSFUNC(countw(&SocialDistancingChange.,:));
						%LET SocialDistancingChange&j = %scan(&SocialDistancingChange.,&j,:);
						%LET BETAChange&j = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &&SocialDistancingChange&j));
						%LET R_T_Change&j = %SYSEVALF(&&BETAChange&j / &GAMMA. * &Population.);
						%LET ISOChangeDate&j = %scan(&ISOChangeDate.,&j,:);
						%LET ISOChangeEvent&j = %scan(&ISOChangeEvent.,&j,:);
						%LET sdchangetitle = &sdchangetitle. (%sysfunc(INPUTN(&&ISOChangeDate&j., date10.), date9.) / &&ISOChangeEvent&j / %SYSFUNC(round(&&R_T_Change&j,.01)) / %SYSEVALF(&&SocialDistancingChange&j.*100)%);
					%END; 
				%END;
				%ELSE %DO;
					%LET sdchangetitle=No Adjustment to R0 over time;
				%END;
						*/
		/* If this is a new scenario then run it */
    	%IF &ScenarioExist = 0 %THEN %DO;
			DATA DS_SEIR_SIM;
				FORMAT ModelType $30. DATE ADMIT_DATE DATE9.;		
				ModelType="SEIR with Data Step";
				FORMAT ScenarioName $50. ScenarioNameUnique $100. ScenarioSource $10. ScenarioUser $25.;
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
				/* prevent range below zero on each loop */
				DO SIGMAfraction = 0.8 TO 1.2 BY 0.1;
					SIGMAINV = 1/(SIGMAfraction*&SIGMA.);
					SIGMAfraction = round(SIGMAfraction,.00001);
					DO RECOVERYDAYSfraction = 0.8 TO 1.2 BY 0.1;
                    RECOVERYDAYS = RECOVERYDAYSfraction * &RecoveryDays;
					RECOVERYDAYSfraction = round(RECOVERYDAYSfraction,.00001);
                        DO SOCIALDfraction = -.2 TO .2 BY 0.1;
						SOCIALD = SOCIALDfraction + &SocialDistancing;
						SOCIALDfraction = round(SOCIALDfraction,.00001);
						IF SOCIALD >=0 and SOCIALD<=1 THEN DO; 
							GAMMA = 1 / RECOVERYDAYS;
							kBETA = ((2 ** (1 / &doublingtime.) - 1) + GAMMA) / 
											&Population. * (1 - SOCIALD);
							%DO j = 1 %TO %SYSFUNC(countw(&SocialDistancingChange.,:));
								BETAChange&j = ((2 ** (1 / &doublingtime.) - 1) + GAMMA) / 
												&Population. * (1 - &&SocialDistancingChange&j);
							%END;				
							byinc = 0.1;
							DO DAY = 0 TO &N_DAYS. by byinc;
								IF DAY = 0 THEN DO;
									S_N = &Population. - (&I. / &DiagnosedRate.) - &InitRecovered.;
									E_N = &E.;
									I_N = &I. / &DiagnosedRate.;
									R_N = &InitRecovered.;
									BETA = kBETA;
									N = SUM(S_N, E_N, I_N, R_N);
								END;
								ELSE DO;
									BETA = LAG_BETA * (1 - &BETA_DECAY.);
									S_N = LAG_S - (BETA * LAG_S * LAG_I)*byinc;
									E_N = LAG_E + (BETA * LAG_S * LAG_I - SIGMAINV * LAG_E)*byinc;
									I_N = LAG_I + (SIGMAINV * LAG_E - GAMMA * LAG_I)*byinc;
									R_N = LAG_R + (GAMMA * LAG_I)*byinc;
									N = SUM(S_N, E_N, I_N, R_N);
									SCALE = LAG_N / N;
									IF S_N < 0 THEN S_N = 0;
									IF E_N < 0 THEN E_N = 0;
									IF I_N < 0 THEN I_N = 0;
									IF R_N < 0 THEN R_N = 0;
									S_N = SCALE*S_N;
									E_N = SCALE*E_N;
									I_N = SCALE*I_N;
									R_N = SCALE*R_N;
								END;
								LAG_S = S_N;
								LAG_E = E_N;
								LAG_I = I_N;
								LAG_R = R_N;
								LAG_N = N;
								DATE = &DAY_ZERO. + int(DAY); /* need current date to determine when to put step change in Social Distancing */
								%DO j = 1 %TO %SYSFUNC(countw(&SocialDistancingChange.,:));
									%IF j = 1 %THEN %DO;
										IF date = &&ISOChangeDate&j THEN BETA = BETAChange&j.;
									%END; %ELSE %DO;
										IF date = &&ISOChangeDate&j THEN BETA = BETAChange&j.;
									%END;
								%END;
								LAG_BETA = BETA;
								IF abs(DAY - round(DAY,1)) < byinc/10 THEN DO;
									DATE = &DAY_ZERO. + round(DAY,1); /* brought forward from post-processing: examine location impact on ISOChangeDate* */
									OUTPUT;
								END;
							END;
						END;
						END;
					END;
				END;
				DROP LAG: BETA byinc kBETA GAMMA BETAChange:;
			RUN;

			DATA DS_SEIR;
				SET DS_SEIR_SIM;
				WHERE SIGMAfraction=1 and RECOVERYDAYSfraction=1 and SOCIALDfraction=0;
				/* START: Common Post-Processing Across each Model Type and Approach */
					NEWINFECTED=LAG&IncubationPeriod(SUM(LAG(SUM(S_N,E_N)),-1*SUM(S_N,E_N)));
					IF NEWINFECTED < 0 THEN NEWINFECTED=0;
					HOSP = NEWINFECTED * &HOSP_RATE. * &MarketSharePercent.;
					ICU = NEWINFECTED * &ICU_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					VENT = NEWINFECTED * &VENT_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					ECMO = NEWINFECTED * &ECMO_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					DIAL = NEWINFECTED * &DIAL_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					Fatality = NEWINFECTED * &FatalityRate * &MarketSharePercent. * &HOSP_RATE.;
					MARKET_HOSP = NEWINFECTED * &HOSP_RATE.;
					MARKET_ICU = NEWINFECTED * &ICU_RATE. * &HOSP_RATE.;
					MARKET_VENT = NEWINFECTED * &VENT_RATE. * &HOSP_RATE.;
					MARKET_ECMO = NEWINFECTED * &ECMO_RATE. * &HOSP_RATE.;
					MARKET_DIAL = NEWINFECTED * &DIAL_RATE. * &HOSP_RATE.;
					Market_Fatality = NEWINFECTED * &FatalityRate. * &HOSP_RATE.;
					CUMULATIVE_SUM_HOSP + HOSP;
					CUMULATIVE_SUM_ICU + ICU;
					CUMULATIVE_SUM_VENT + VENT;
					CUMULATIVE_SUM_ECMO + ECMO;
					CUMULATIVE_SUM_DIAL + DIAL;
					Cumulative_sum_fatality + Fatality;
					CUMULATIVE_SUM_MARKET_HOSP + MARKET_HOSP;
					CUMULATIVE_SUM_MARKET_ICU + MARKET_ICU;
					CUMULATIVE_SUM_MARKET_VENT + MARKET_VENT;
					CUMULATIVE_SUM_MARKET_ECMO + MARKET_ECMO;
					CUMULATIVE_SUM_MARKET_DIAL + MARKET_DIAL;
					cumulative_Sum_Market_Fatality + Market_Fatality;
					CUMADMITLAGGED=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_HOSP),1) ;
					CUMICULAGGED=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_ICU),1) ;
					CUMVENTLAGGED=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_VENT),1) ;
					CUMECMOLAGGED=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_ECMO),1) ;
					CUMDIALLAGGED=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_DIAL),1) ;
					CUMMARKETADMITLAG=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_MARKET_HOSP));
					CUMMARKETICULAG=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_MARKET_ICU));
					CUMMARKETVENTLAG=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_MARKET_VENT));
					CUMMARKETECMOLAG=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_MARKET_ECMO));
					CUMMARKETDIALLAG=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_MARKET_DIAL));
					ARRAY FIXINGDOT _NUMERIC_;
					DO OVER FIXINGDOT;
						IF FIXINGDOT=. THEN FIXINGDOT=0;
					END;
					HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_HOSP-CUMADMITLAGGED,1);
					ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_ICU-CUMICULAGGED,1);
					VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_VENT-CUMVENTLAGGED,1);
					ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_ECMO-CUMECMOLAGGED,1);
					DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_DIAL-CUMDIALLAGGED,1);
					Deceased_Today = Fatality;
					Total_Deaths = Cumulative_sum_fatality;
					MedSurgOccupancy=Hospital_Occupancy-ICU_Occupancy;
					MARKET_HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_HOSP-CUMMARKETADMITLAG,1);
					MARKET_ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_ICU-CUMMARKETICULAG,1);
					MARKET_VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_VENT-CUMMARKETVENTLAG,1);
					MARKET_ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_ECMO-CUMMARKETECMOLAG,1);
					MARKET_DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_DIAL-CUMMARKETDIALLAG,1);	
					Market_Deceased_Today = Market_Fatality;
					Market_Total_Deaths = cumulative_Sum_Market_Fatality;
					Market_MEdSurg_Occupancy=Market_Hospital_Occupancy-MArket_ICU_Occupancy;
					DATE = &DAY_ZERO. + round(DAY,1);
					ADMIT_DATE = SUM(DATE, &IncubationPeriod.);
					FORMAT ISOChangeEvent $30.;
					%IF %sysevalf(%superq(ISOChangeDate)=,boolean)=0 %THEN %DO;
						%DO j = 1 %TO %SYSFUNC(countw(&ISOChangeDate.,:)); 
							IF DATE = &&ISOChangeDate&j THEN DO;
								ISOChangeEvent = "&&ISOChangeEvent&j";
								/* the values in EventY_Multiplier will get multiplied by Peak values later in the code */
								EventY_Multiplier = 1.1+MOD(&j,2)/10;
							END;
						%END;
					%END;
					%ELSE %DO;
						ISOChangeEvent = '';
						EventY_Multiplier = .;
					%END;
				/* END: Common Post-Processing Across each Model Type and Approach */
				DROP CUM: SIGMAINV SIGMAfraction RECOVERYDAYSfraction RECOVERYDAYS SOCIALDfraction SOCIALD;
			RUN;

		/* calculate key output measures for all scenarios as input to uncertainty bounds */
            /* use a skeleton from the normal post-processing to processes every scenario.
                by statement used for separating scenarios - order by in sql above prepares this
                note that lag function used in conditional logic can be very tricky.
                The code below has logic to override the lag at the start of each by group.
            */
			DATA DS_SEIR_SIM;
				FORMAT ScenarioName $50. ScenarioNameUnique $100. ScenarioSource $10. ScenarioUser $25.;
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
				RETAIN counter CUMULATIVE_SUM_HOSP CUMULATIVE_SUM_ICU CUMULATIVE_SUM_VENT CUMULATIVE_SUM_ECMO CUMULATIVE_SUM_DIAL;
				SET DS_SEIR_SIM;
                by SIGMAfraction RECOVERYDAYSfraction SOCIALDfraction;
                    if first.SOCIALD then do;
                        counter = 1;
                        CUMULATIVE_SUM_HOSP=0;
                        CUMULATIVE_SUM_ICU=0;
                        CUMULATIVE_SUM_VENT=0;
                        CUMULATIVE_SUM_ECMO=0;
                        CUMULATIVE_SUM_DIAL=0;
                    end;
                    else do;
                        counter+1;
                    end;
				/* START: Common Post-Processing Across each Model Type and Approach */
					NEWINFECTED=LAG&IncubationPeriod(SUM(LAG(sum(S_N,E_N)),-1*sum(S_N,E_N)));
                        if counter<&IncubationPeriod then NEWINFECTED=.; /* reset the lag for by group */

					IF NEWINFECTED < 0 THEN NEWINFECTED=0;
					HOSP = NEWINFECTED * &HOSP_RATE. * &MarketSharePercent.;
					ICU = NEWINFECTED * &ICU_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					VENT = NEWINFECTED * &VENT_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					ECMO = NEWINFECTED * &ECMO_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					DIAL = NEWINFECTED * &DIAL_RATE. * &MarketSharePercent. * &HOSP_RATE.;

					CUMULATIVE_SUM_HOSP + HOSP;
					CUMULATIVE_SUM_ICU + ICU;
					CUMULATIVE_SUM_VENT + VENT;
					CUMULATIVE_SUM_ECMO + ECMO;
					CUMULATIVE_SUM_DIAL + DIAL;

                    CUMADMITLAGGED=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_HOSP),1) ;
                        if counter<=&HOSP_LOS then CUMADMITLAGGED=.; /* reset the lag for by group */
					CUMICULAGGED=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_ICU),1) ;
                        if counter<=&ICU_LOS then CUMICULAGGED=.; /* reset the lag for by group */
					CUMVENTLAGGED=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_VENT),1) ;
                        if counter<=&VENT_LOS then CUMVENTLAGGED=.; /* reset the lag for by group */
					CUMECMOLAGGED=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_ECMO),1) ;
                        if counter<=&ECMO_LOS then CUMECMOLAGGED=.; /* reset the lag for by group */
					CUMDIALLAGGED=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_DIAL),1) ;
                        if counter<=&DIAL_LOS then CUMDIALLAGGED=.; /* reset the lag for by group */

					ARRAY FIXINGDOT _NUMERIC_;
					DO OVER FIXINGDOT;
						IF FIXINGDOT=. THEN FIXINGDOT=0;
					END;
					
                    HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_HOSP-CUMADMITLAGGED,1);
					ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_ICU-CUMICULAGGED,1);
					VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_VENT-CUMVENTLAGGED,1);
					ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_ECMO-CUMECMOLAGGED,1);
					DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_DIAL-CUMDIALLAGGED,1);
					
				/* END: Common Post-Processing Across each Model Type and Approach */
                KEEP ModelType ScenarioIndex DATE HOSPITAL_OCCUPANCY ICU_OCCUPANCY VENT_OCCUPANCY ECMO_OCCUPANCY DIAL_OCCUPANCY SIGMAfraction RECOVERYDAYS SOCIALD;
			RUN;

		/* merge scenario data with uncertain bounds */
            PROC SQL noprint;
                create table DS_SEIR as
                    select * from
                        (select * from work.DS_SEIR) B 
                        left join
                        (select min(HOSPITAL_OCCUPANCY) as LOWER_HOSPITAL_OCCUPANCY, 
                                min(ICU_OCCUPANCY) as LOWER_ICU_OCCUPANCY, 
                                min(VENT_OCCUPANCY) as LOWER_VENT_OCCUPANCY, 
                                min(ECMO_OCCUPANCY) as LOWER_ECMO_OCCUPANCY, 
                                min(DIAL_OCCUPANCY) as LOWER_DIAL_OCCUPANCY,
                                max(HOSPITAL_OCCUPANCY) as UPPER_HOSPITAL_OCCUPANCY, 
                                max(ICU_OCCUPANCY) as UPPER_ICU_OCCUPANCY, 
                                max(VENT_OCCUPANCY) as UPPER_VENT_OCCUPANCY, 
                                max(ECMO_OCCUPANCY) as UPPER_ECMO_OCCUPANCY, 
                                max(DIAL_OCCUPANCY) as UPPER_DIAL_OCCUPANCY,
                                Date, ModelType, ScenarioIndex
                            from DS_SEIR_SIM
                            group by Date, ModelType, ScenarioIndex
                        ) U 
                        on B.ModelType=U.ModelType and B.ScenarioIndex=U.ScenarioIndex and B.DATE=U.DATE
                    order by ScenarioIndex, ModelType, Date
                ;
                drop table DS_SEIR_SIM;
            QUIT;

			PROC APPEND base=work.MODEL_FINAL data=DS_SEIR NOWARN FORCE; run;
			PROC SQL; drop table DS_SEIR; QUIT;

		%END;

		%IF &PLOTS. = YES %THEN %DO;
			PROC SGPLOT DATA=work.MODEL_FINAL;
				where ModelType='SEIR with Data Step' and ScenarioIndex=&ScenarioIndex.;
				TITLE "Daily Occupancy - Data Step SEIR Approach";
				TITLE2 "Scenario: &Scenario., Initial R0: %SYSFUNC(round(&R_T.,.01)) with Initial Social Distancing of %SYSEVALF(&SocialDistancing.*100)%";
				TITLE3 "&sdchangetitle.";
				SERIES X=DATE Y=HOSPITAL_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=ICU_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=VENT_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=ECMO_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=DIAL_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				XAXIS LABEL="Date";
				YAXIS LABEL="Daily Occupancy";
			RUN;
			TITLE; TITLE2; TITLE3;

			PROC SGPLOT DATA=work.MODEL_FINAL;
				where ModelType='SEIR with Data Step' and ScenarioIndex=&ScenarioIndex.;
				TITLE "Daily Occupancy - Data Step SEIR Approach With Uncertainty Bounds";
				TITLE2 "Scenario: &Scenario., Initial R0: %SYSFUNC(round(&R_T.,.01)) with Initial Social Distancing of %SYSEVALF(&SocialDistancing.*100)%";
				TITLE3 "&sdchangetitle.";
					
                BAND x=DATE lower=LOWER_HOSPITAL_OCCUPANCY upper=UPPER_HOSPITAL_OCCUPANCY / fillattrs=(color=blue transparency=.8) name="b1";
                BAND x=DATE lower=LOWER_ICU_OCCUPANCY upper=UPPER_ICU_OCCUPANCY / fillattrs=(color=red transparency=.8) name="b2";
                BAND x=DATE lower=LOWER_VENT_OCCUPANCY upper=UPPER_VENT_OCCUPANCY / fillattrs=(color=green transparency=.8) name="b3";
                BAND x=DATE lower=LOWER_ECMO_OCCUPANCY upper=UPPER_ECMO_OCCUPANCY / fillattrs=(color=brown transparency=.8) name="b4";
                BAND x=DATE lower=LOWER_DIAL_OCCUPANCY upper=UPPER_DIAL_OCCUPANCY / fillattrs=(color=purple transparency=.8) name="b5";
                SERIES X=DATE Y=HOSPITAL_OCCUPANCY / LINEATTRS=(color=blue THICKNESS=2) name="l1";
				SERIES X=DATE Y=ICU_OCCUPANCY / LINEATTRS=(color=red THICKNESS=2) name="l2";
				SERIES X=DATE Y=VENT_OCCUPANCY / LINEATTRS=(color=green THICKNESS=2) name="l3";
				SERIES X=DATE Y=ECMO_OCCUPANCY / LINEATTRS=(color=brown THICKNESS=2) name="l4";
				SERIES X=DATE Y=DIAL_OCCUPANCY / LINEATTRS=(color=purple THICKNESS=2) name="l5";
                keylegend "l1" "l2" "l3" "l4" "l5";
                
				XAXIS LABEL="Date";
				YAXIS LABEL="Daily Occupancy";
			RUN;
			TITLE; TITLE2; TITLE3;
		%END;

	/* DATA STEP APPROACH FOR SIR */
		/* these are the calculations for variables used from above:
			* calculated parameters used in model post-processing;
				%LET HOSP_RATE = %SYSEVALF(&Admission_Rate. * &DiagnosedRate.);
				%LET ICU_RATE = %SYSEVALF(&ICUPercent. * &DiagnosedRate.);
				%LET VENT_RATE = %SYSEVALF(&VentPErcent. * &DiagnosedRate.);
			* calculated parameters used in models;
				%LET I = %SYSEVALF(&KnownAdmits. / 
											&MarketSharePercent. / 
												(&Admission_Rate. * &DiagnosedRate.));
				%LET GAMMA = %SYSEVALF(1 / &RecoveryDays.);
				%IF &SIGMA. <= 0 %THEN %LET SIGMA = 0.00000001;
					%LET SIGMAINV = %SYSEVALF(1 / &SIGMA.);
				%LET BETA = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &SocialDistancing.));
				%LET R_T = %SYSEVALF(&BETA. / &GAMMA. * &Population.);

				%IF %sysevalf(%superq(SocialDistancingChange)=,boolean)=0 %THEN %DO;
					%LET sdchangetitle=Adjust R0 (Date / Event / R0 / Social Distancing):;
					%DO j = 1 %TO %SYSFUNC(countw(&SocialDistancingChange.,:));
						%LET SocialDistancingChange&j = %scan(&SocialDistancingChange.,&j,:);
						%LET BETAChange&j = %SYSEVALF(((2 ** (1 / &doublingtime.) - 1) + &GAMMA.) / 
												&Population. * (1 - &&SocialDistancingChange&j));
						%LET R_T_Change&j = %SYSEVALF(&&BETAChange&j / &GAMMA. * &Population.);
						%LET ISOChangeDate&j = %scan(&ISOChangeDate.,&j,:);
						%LET ISOChangeEvent&j = %scan(&ISOChangeEvent.,&j,:);
						%LET sdchangetitle = &sdchangetitle. (%sysfunc(INPUTN(&&ISOChangeDate&j., date10.), date9.) / &&ISOChangeEvent&j / %SYSFUNC(round(&&R_T_Change&j,.01)) / %SYSEVALF(&&SocialDistancingChange&j.*100)%);
					%END; 
				%END;
				%ELSE %DO;
					%LET sdchangetitle=No Adjustment to R0 over time;
				%END;
						*/
		/* If this is a new scenario then run it */
    	%IF &ScenarioExist = 0 %THEN %DO;
			DATA DS_SIR_SIM;
				FORMAT ModelType $30. DATE ADMIT_DATE DATE9.;		
				ModelType="SIR with Data Step";
				FORMAT ScenarioName $50. ScenarioNameUnique $100. ScenarioSource $10. ScenarioUser $25.;
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
				/* prevent range below zero on each loop */
					DO RECOVERYDAYSfraction = 0.8 TO 1.2 BY 0.1;
                    RECOVERYDAYS = RECOVERYDAYSfraction*&RecoveryDays;
					RECOVERYDAYSfraction = round(RECOVERYDAYSfraction,.00001);
                        DO SOCIALDfraction = -.2 TO .2 BY 0.1;
						SOCIALD = SOCIALDfraction + &SocialDistancing;
						SOCIALDfraction = round(SOCIALDfraction,.00001);
						IF SOCIALD >=0 and SOCIALD<=1 THEN DO; 
							GAMMA = 1 / RECOVERYDAYS;
							kBETA = ((2 ** (1 / &doublingtime.) - 1) + GAMMA) / 
											&Population. * (1 - SOCIALD);
							%DO j = 1 %TO %SYSFUNC(countw(&SocialDistancingChange.,:));
								BETAChange&j = ((2 ** (1 / &doublingtime.) - 1) + GAMMA) / 
												&Population. * (1 - &&SocialDistancingChange&j);
							%END;
							byinc = 0.1;
							DO DAY = 0 TO &N_DAYS. by byinc;
								IF DAY = 0 THEN DO;
									S_N = &Population. - (&I. / &DiagnosedRate.) - &InitRecovered.;
									I_N = &I./&DiagnosedRate.;
									R_N = &InitRecovered.;
									BETA = kBETA;
									N = SUM(S_N, I_N, R_N);
								END;
								ELSE DO;
									BETA = LAG_BETA * (1- &BETA_DECAY.);
									S_N = LAG_S - (BETA * LAG_S * LAG_I)*byinc;
									I_N = LAG_I + (BETA * LAG_S * LAG_I - GAMMA * LAG_I)*byinc;
									R_N = LAG_R + (GAMMA * LAG_I)*byinc;
									N = SUM(S_N, I_N, R_N);
									SCALE = LAG_N / N;
									IF S_N < 0 THEN S_N = 0;
									IF I_N < 0 THEN I_N = 0;
									IF R_N < 0 THEN R_N = 0;
									S_N = SCALE*S_N;
									I_N = SCALE*I_N;
									R_N = SCALE*R_N;
								END;
								LAG_S = S_N;
								E_N = 0; LAG_E = E_N; /* placeholder for post-processing of SIR model */
								LAG_I = I_N;
								LAG_R = R_N;
								LAG_N = N;
								DATE = &DAY_ZERO. + int(DAY); /* need current date to determine when to put step change in Social Distancing */
								%DO j = 1 %TO %SYSFUNC(countw(&SocialDistancingChange.,:));
									%IF j = 1 %THEN %DO;
										IF date = &&ISOChangeDate&j THEN BETA = BETAChange&j.;
									%END; %ELSE %DO;
										IF date = &&ISOChangeDate&j THEN BETA = BETAChange&j.;
									%END;
								%END;
								LAG_BETA = BETA;
								IF abs(DAY - round(DAY,1)) < byinc/10 THEN DO;
									DATE = &DAY_ZERO. + round(DAY,1); /* brought forward from post-processing: examine location impact on ISOChangeDate* */
									OUTPUT;
								END;
							END;
						END;
						END;
					END;
				DROP LAG: BETA byinc kBETA GAMMA BETAChange:;
			RUN;

		/* use the center point of the ranges for the request scenario inputs */
			DATA DS_SIR;
				SET DS_SIR_SIM;
				WHERE RECOVERYDAYSfraction=1 and SOCIALDfraction=0;
				/* START: Common Post-Processing Across each Model Type and Approach */
					NEWINFECTED=LAG&IncubationPeriod(SUM(LAG(SUM(S_N,E_N)),-1*SUM(S_N,E_N)));
					IF NEWINFECTED < 0 THEN NEWINFECTED=0;
					HOSP = NEWINFECTED * &HOSP_RATE. * &MarketSharePercent.;
					ICU = NEWINFECTED * &ICU_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					VENT = NEWINFECTED * &VENT_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					ECMO = NEWINFECTED * &ECMO_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					DIAL = NEWINFECTED * &DIAL_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					Fatality = NEWINFECTED * &FatalityRate * &MarketSharePercent. * &HOSP_RATE.;
					MARKET_HOSP = NEWINFECTED * &HOSP_RATE.;
					MARKET_ICU = NEWINFECTED * &ICU_RATE. * &HOSP_RATE.;
					MARKET_VENT = NEWINFECTED * &VENT_RATE. * &HOSP_RATE.;
					MARKET_ECMO = NEWINFECTED * &ECMO_RATE. * &HOSP_RATE.;
					MARKET_DIAL = NEWINFECTED * &DIAL_RATE. * &HOSP_RATE.;
					Market_Fatality = NEWINFECTED * &FatalityRate. * &HOSP_RATE.;
					CUMULATIVE_SUM_HOSP + HOSP;
					CUMULATIVE_SUM_ICU + ICU;
					CUMULATIVE_SUM_VENT + VENT;
					CUMULATIVE_SUM_ECMO + ECMO;
					CUMULATIVE_SUM_DIAL + DIAL;
					Cumulative_sum_fatality + Fatality;
					CUMULATIVE_SUM_MARKET_HOSP + MARKET_HOSP;
					CUMULATIVE_SUM_MARKET_ICU + MARKET_ICU;
					CUMULATIVE_SUM_MARKET_VENT + MARKET_VENT;
					CUMULATIVE_SUM_MARKET_ECMO + MARKET_ECMO;
					CUMULATIVE_SUM_MARKET_DIAL + MARKET_DIAL;
					cumulative_Sum_Market_Fatality + Market_Fatality;
					CUMADMITLAGGED=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_HOSP),1) ;
					CUMICULAGGED=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_ICU),1) ;
					CUMVENTLAGGED=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_VENT),1) ;
					CUMECMOLAGGED=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_ECMO),1) ;
					CUMDIALLAGGED=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_DIAL),1) ;
					CUMMARKETADMITLAG=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_MARKET_HOSP));
					CUMMARKETICULAG=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_MARKET_ICU));
					CUMMARKETVENTLAG=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_MARKET_VENT));
					CUMMARKETECMOLAG=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_MARKET_ECMO));
					CUMMARKETDIALLAG=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_MARKET_DIAL));
					ARRAY FIXINGDOT _NUMERIC_;
					DO OVER FIXINGDOT;
						IF FIXINGDOT=. THEN FIXINGDOT=0;
					END;
					HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_HOSP-CUMADMITLAGGED,1);
					ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_ICU-CUMICULAGGED,1);
					VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_VENT-CUMVENTLAGGED,1);
					ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_ECMO-CUMECMOLAGGED,1);
					DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_DIAL-CUMDIALLAGGED,1);
					Deceased_Today = Fatality;
					Total_Deaths = Cumulative_sum_fatality;
					MedSurgOccupancy=Hospital_Occupancy-ICU_Occupancy;
					MARKET_HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_HOSP-CUMMARKETADMITLAG,1);
					MARKET_ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_ICU-CUMMARKETICULAG,1);
					MARKET_VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_VENT-CUMMARKETVENTLAG,1);
					MARKET_ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_ECMO-CUMMARKETECMOLAG,1);
					MARKET_DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_MARKET_DIAL-CUMMARKETDIALLAG,1);	
					Market_Deceased_Today = Market_Fatality;
					Market_Total_Deaths = cumulative_Sum_Market_Fatality;
					Market_MEdSurg_Occupancy=Market_Hospital_Occupancy-MArket_ICU_Occupancy;
					DATE = &DAY_ZERO. + round(DAY,1);
					ADMIT_DATE = SUM(DATE, &IncubationPeriod.);
					FORMAT ISOChangeEvent $30.;
					%IF %sysevalf(%superq(ISOChangeDate)=,boolean)=0 %THEN %DO;
						%DO j = 1 %TO %SYSFUNC(countw(&ISOChangeDate.,:)); 
							IF DATE = &&ISOChangeDate&j THEN DO;
								ISOChangeEvent = "&&ISOChangeEvent&j";
								/* the values in EventY_Multiplier will get multiplied by Peak values later in the code */
								EventY_Multiplier = 1.1+MOD(&j,2)/10;
							END;
						%END;
					%END;
					%ELSE %DO;
						ISOChangeEvent = '';
						EventY_Multiplier = .;
					%END;
				/* END: Common Post-Processing Across each Model Type and Approach */
				DROP CUM: RECOVERYDAYSfraction RECOVERYDAYS SOCIALDfraction SOCIALD;
			RUN;

		/* calculate key output measures for all scenarios as input to uncertainty bounds */
            /* use a skeleton from the normal post-processing to processes every scenario.
                by statement used for separating scenarios - order by in sql above prepares this
                note that lag function used in conditional logic can be very tricky.
                The code below has logic to override the lag at the start of each by group.
            */
			DATA DS_SIR_SIM;
				FORMAT ScenarioName $50. ScenarioNameUnique $100. ScenarioSource $10. ScenarioUser $25.;
				ScenarioName="&Scenario.";
				ScenarioIndex=&ScenarioIndex.;
				ScenarioUser="&SYSUSERID.";
				ScenarioSource="&ScenarioSource.";
				ScenarioNameUnique=cats("&Scenario.",' (',ScenarioIndex,'-',"&SYSUSERID.",'-',"&ScenarioSource.",')');
				RETAIN counter CUMULATIVE_SUM_HOSP CUMULATIVE_SUM_ICU CUMULATIVE_SUM_VENT CUMULATIVE_SUM_ECMO CUMULATIVE_SUM_DIAL;
				SET DS_SIR_SIM;
                by RECOVERYDAYSfraction SOCIALDfraction;
                    if first.SOCIALD then do;
                        counter = 1;
                        CUMULATIVE_SUM_HOSP=0;
                        CUMULATIVE_SUM_ICU=0;
                        CUMULATIVE_SUM_VENT=0;
                        CUMULATIVE_SUM_ECMO=0;
                        CUMULATIVE_SUM_DIAL=0;
                    end;
                    else do;
                        counter+1;
                    end;
				/* START: Common Post-Processing Across each Model Type and Approach */
					NEWINFECTED=LAG&IncubationPeriod(SUM(LAG(S_N),-1*S_N));
                        if counter<&IncubationPeriod then NEWINFECTED=.; /* reset the lag for by group */

					IF NEWINFECTED < 0 THEN NEWINFECTED=0;
					HOSP = NEWINFECTED * &HOSP_RATE. * &MarketSharePercent.;
					ICU = NEWINFECTED * &ICU_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					VENT = NEWINFECTED * &VENT_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					ECMO = NEWINFECTED * &ECMO_RATE. * &MarketSharePercent. * &HOSP_RATE.;
					DIAL = NEWINFECTED * &DIAL_RATE. * &MarketSharePercent. * &HOSP_RATE.;

					CUMULATIVE_SUM_HOSP + HOSP;
					CUMULATIVE_SUM_ICU + ICU;
					CUMULATIVE_SUM_VENT + VENT;
					CUMULATIVE_SUM_ECMO + ECMO;
					CUMULATIVE_SUM_DIAL + DIAL;

                    CUMADMITLAGGED=ROUND(LAG&HOSP_LOS.(CUMULATIVE_SUM_HOSP),1) ;
                        if counter<=&HOSP_LOS then CUMADMITLAGGED=.; /* reset the lag for by group */
					CUMICULAGGED=ROUND(LAG&ICU_LOS.(CUMULATIVE_SUM_ICU),1) ;
                        if counter<=&ICU_LOS then CUMICULAGGED=.; /* reset the lag for by group */
					CUMVENTLAGGED=ROUND(LAG&VENT_LOS.(CUMULATIVE_SUM_VENT),1) ;
                        if counter<=&VENT_LOS then CUMVENTLAGGED=.; /* reset the lag for by group */
					CUMECMOLAGGED=ROUND(LAG&ECMO_LOS.(CUMULATIVE_SUM_ECMO),1) ;
                        if counter<=&ECMO_LOS then CUMECMOLAGGED=.; /* reset the lag for by group */
					CUMDIALLAGGED=ROUND(LAG&DIAL_LOS.(CUMULATIVE_SUM_DIAL),1) ;
                        if counter<=&DIAL_LOS then CUMDIALLAGGED=.; /* reset the lag for by group */

					ARRAY FIXINGDOT _NUMERIC_;
					DO OVER FIXINGDOT;
						IF FIXINGDOT=. THEN FIXINGDOT=0;
					END;
					
                    HOSPITAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_HOSP-CUMADMITLAGGED,1);
					ICU_OCCUPANCY= ROUND(CUMULATIVE_SUM_ICU-CUMICULAGGED,1);
					VENT_OCCUPANCY= ROUND(CUMULATIVE_SUM_VENT-CUMVENTLAGGED,1);
					ECMO_OCCUPANCY= ROUND(CUMULATIVE_SUM_ECMO-CUMECMOLAGGED,1);
					DIAL_OCCUPANCY= ROUND(CUMULATIVE_SUM_DIAL-CUMDIALLAGGED,1);
					
				/* END: Common Post-Processing Across each Model Type and Approach */
                KEEP ModelType ScenarioIndex DATE HOSPITAL_OCCUPANCY ICU_OCCUPANCY VENT_OCCUPANCY ECMO_OCCUPANCY DIAL_OCCUPANCY RECOVERYDAYS SOCIALD;
			RUN;

		/* merge scenario data with uncertain bounds */
            PROC SQL noprint;
                create table DS_SIR as
                    select * from
                        (select * from work.DS_SIR) B 
                        left join
                        (select min(HOSPITAL_OCCUPANCY) as LOWER_HOSPITAL_OCCUPANCY, 
                                min(ICU_OCCUPANCY) as LOWER_ICU_OCCUPANCY, 
                                min(VENT_OCCUPANCY) as LOWER_VENT_OCCUPANCY, 
                                min(ECMO_OCCUPANCY) as LOWER_ECMO_OCCUPANCY, 
                                min(DIAL_OCCUPANCY) as LOWER_DIAL_OCCUPANCY,
                                max(HOSPITAL_OCCUPANCY) as UPPER_HOSPITAL_OCCUPANCY, 
                                max(ICU_OCCUPANCY) as UPPER_ICU_OCCUPANCY, 
                                max(VENT_OCCUPANCY) as UPPER_VENT_OCCUPANCY, 
                                max(ECMO_OCCUPANCY) as UPPER_ECMO_OCCUPANCY, 
                                max(DIAL_OCCUPANCY) as UPPER_DIAL_OCCUPANCY,
                                Date, ModelType, ScenarioIndex
                            from DS_SIR_SIM
                            group by Date, ModelType, ScenarioIndex
                        ) U 
                        on B.ModelType=U.ModelType and B.ScenarioIndex=U.ScenarioIndex and B.DATE=U.DATE
                    order by ScenarioIndex, ModelType, Date
                ;
                drop table DS_SIR_SIM;
            QUIT;

			PROC APPEND base=work.MODEL_FINAL data=DS_SIR NOWARN FORCE; run;
			PROC SQL; drop table DS_SIR; QUIT;

		%END;

		%IF &PLOTS. = YES %THEN %DO;
			PROC SGPLOT DATA=work.MODEL_FINAL;
				where ModelType='SIR with Data Step' and ScenarioIndex=&ScenarioIndex.;
				TITLE "Daily Occupancy - Data Step SIR Approach";
				TITLE2 "Scenario: &Scenario., Initial R0: %SYSFUNC(round(&R_T.,.01)) with Initial Social Distancing of %SYSEVALF(&SocialDistancing.*100)%";
				TITLE3 "&sdchangetitle.";
				SERIES X=DATE Y=HOSPITAL_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=ICU_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=VENT_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=ECMO_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				SERIES X=DATE Y=DIAL_OCCUPANCY / LINEATTRS=(THICKNESS=2);
				XAXIS LABEL="Date";
				YAXIS LABEL="Daily Occupancy";
			RUN;
			TITLE; TITLE2; TITLE3;

			PROC SGPLOT DATA=work.MODEL_FINAL;
				where ModelType='SIR with Data Step' and ScenarioIndex=&ScenarioIndex.;
				TITLE "Daily Occupancy - Data Step SIR Approach With Uncertainty Bounds";
				TITLE2 "Scenario: &Scenario., Initial R0: %SYSFUNC(round(&R_T.,.01)) with Initial Social Distancing of %SYSEVALF(&SocialDistancing.*100)%";
				TITLE3 "&sdchangetitle.";
					
                BAND x=DATE lower=LOWER_HOSPITAL_OCCUPANCY upper=UPPER_HOSPITAL_OCCUPANCY / fillattrs=(color=blue transparency=.8) name="b1";
                BAND x=DATE lower=LOWER_ICU_OCCUPANCY upper=UPPER_ICU_OCCUPANCY / fillattrs=(color=red transparency=.8) name="b2";
                BAND x=DATE lower=LOWER_VENT_OCCUPANCY upper=UPPER_VENT_OCCUPANCY / fillattrs=(color=green transparency=.8) name="b3";
                BAND x=DATE lower=LOWER_ECMO_OCCUPANCY upper=UPPER_ECMO_OCCUPANCY / fillattrs=(color=brown transparency=.8) name="b4";
                BAND x=DATE lower=LOWER_DIAL_OCCUPANCY upper=UPPER_DIAL_OCCUPANCY / fillattrs=(color=purple transparency=.8) name="b5";
                SERIES X=DATE Y=HOSPITAL_OCCUPANCY / LINEATTRS=(color=blue THICKNESS=2) name="l1";
				SERIES X=DATE Y=ICU_OCCUPANCY / LINEATTRS=(color=red THICKNESS=2) name="l2";
				SERIES X=DATE Y=VENT_OCCUPANCY / LINEATTRS=(color=green THICKNESS=2) name="l3";
				SERIES X=DATE Y=ECMO_OCCUPANCY / LINEATTRS=(color=brown THICKNESS=2) name="l4";
				SERIES X=DATE Y=DIAL_OCCUPANCY / LINEATTRS=(color=purple THICKNESS=2) name="l5";
                keylegend "l1" "l2" "l3" "l4" "l5";
                
				XAXIS LABEL="Date";
				YAXIS LABEL="Daily Occupancy";
			RUN;
			TITLE; TITLE2; TITLE3;
		%END;


    %IF &PLOTS. = YES %THEN %DO;
        /* if multiple models for a single scenarioIndex then plot them */
        PROC SQL noprint;
            select count(*) into :scenplot from (select distinct ModelType from work.MODEL_FINAL where ScenarioIndex=&ScenarioIndex.);
        QUIT;
        %IF &scenplot > 1 %THEN %DO;
            PROC SGPLOT DATA=work.MODEL_FINAL;
                where ScenarioIndex=&ScenarioIndex.;
                TITLE "Daily Hospital Occupancy - All Approaches";
                TITLE2 "Scenario: &Scenario., Initial R0: %SYSFUNC(round(&R_T.,.01)) with Initial Social Distancing of %SYSEVALF(&SocialDistancing.*100)%";
                TITLE3 "&sdchangetitle.";
                SERIES X=DATE Y=HOSPITAL_OCCUPANCY / GROUP=MODELTYPE LINEATTRS=(THICKNESS=2);
                XAXIS LABEL="Date";
                YAXIS LABEL="Daily Occupancy";
            RUN;
            TITLE; TITLE2; TITLE3;
        %END;	
    %END;

    /* code to manage output tables in STORE and CAS table management (coming soon) */
        %IF &ScenarioExist = 0 %THEN %DO;

				/*CREATE FLAGS FOR DAYS WITH PEAK VALUES OF DIFFERENT METRICS*/
					PROC SQL noprint;
						CREATE TABLE work.MODEL_FINAL AS
							SELECT MF.*, HOSP.PEAK_HOSPITAL_OCCUPANCY, ICU.PEAK_ICU_OCCUPANCY, VENT.PEAK_VENT_OCCUPANCY, 
								ECMO.PEAK_ECMO_OCCUPANCY, DIAL.PEAK_DIAL_OCCUPANCY, I.PEAK_I_N, FATAL.PEAK_FATALITY
							FROM work.MODEL_FINAL MF
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, HOSPITAL_OCCUPANCY, 1 AS PEAK_HOSPITAL_OCCUPANCY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING HOSPITAL_OCCUPANCY=MAX(HOSPITAL_OCCUPANCY)
											) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) HOSP
									ON MF.MODELTYPE = HOSP.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = HOSP.SCENARIONAMEUNIQUE
										AND MF.DATE = HOSP.DATE
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, ICU_OCCUPANCY, 1 AS PEAK_ICU_OCCUPANCY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING ICU_OCCUPANCY=MAX(ICU_OCCUPANCY)
											) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) ICU
									ON MF.MODELTYPE = ICU.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = ICU.SCENARIONAMEUNIQUE
										AND MF.DATE = ICU.DATE
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, VENT_OCCUPANCY, 1 AS PEAK_VENT_OCCUPANCY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING VENT_OCCUPANCY=MAX(VENT_OCCUPANCY)
										) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) VENT
									ON MF.MODELTYPE = VENT.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = VENT.SCENARIONAMEUNIQUE
										AND MF.DATE = VENT.DATE
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, ECMO_OCCUPANCY, 1 AS PEAK_ECMO_OCCUPANCY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING ECMO_OCCUPANCY=MAX(ECMO_OCCUPANCY)
										) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) ECMO
									ON MF.MODELTYPE = ECMO.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = ECMO.SCENARIONAMEUNIQUE
										AND MF.DATE = ECMO.DATE
								LEFT JOIN
									(SELECT * FROM
										(SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, DIAL_OCCUPANCY, 1 AS PEAK_DIAL_OCCUPANCY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING DIAL_OCCUPANCY=MAX(DIAL_OCCUPANCY)
										) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) DIAL
									ON MF.MODELTYPE = DIAL.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = DIAL.SCENARIONAMEUNIQUE
										AND MF.DATE = DIAL.DATE
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, I_N, 1 AS PEAK_I_N
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING I_N=MAX(I_N)
										) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) I
									ON MF.MODELTYPE = I.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = I.SCENARIONAMEUNIQUE
										AND MF.DATE = I.DATE
								LEFT JOIN
									(SELECT *
										FROM (SELECT MODELTYPE, SCENARIONAMEUNIQUE, DATE, FATALITY, 1 AS PEAK_FATALITY
											FROM work.MODEL_FINAL
											GROUP BY 1, 2
											HAVING FATALITY=MAX(FATALITY)
										) 
										GROUP BY MODELTYPE, SCENARIONAMEUNIQUE
										HAVING DATE=MIN(DATE)
									) FATAL
									ON MF.MODELTYPE = FATAL.MODELTYPE
										AND MF.SCENARIONAMEUNIQUE = FATAL.SCENARIONAMEUNIQUE
										AND MF.DATE = FATAL.DATE
							ORDER BY SCENARIONAMEUNIQUE, MODELTYPE, DATE;

							/* add EVENTY columns for ploting labels in ISOChangeEvent */
							select name into :varlist separated by ', '
								from dictionary.columns
								where UPCASE(LIBNAME)="WORK" and upcase(memname)="MODEL_FINAL" and upcase(name) ne 'EVENTY_MULTIPLIER';
							create table work.MODEL_FINAL as
								select * from
									(select &varlist from work.MODEL_FINAL) m1
									left join
									(
										select t1.ScenarioNameUnique, t1.ModelType, t1.Date,
												round(t1.EventY_Multiplier * t2.HOSPITAL_OCCUPANCY,1) as EventY_HOSPITAL_OCCUPANCY,
												round(t1.EventY_Multiplier * t3.ICU_OCCUPANCY,1) as EventY_ICU_OCCUPANCY,
												round(t1.EventY_Multiplier * t4.DIAL_OCCUPANCY,1) as EventY_DIAL_OCCUPANCY,
												round(t1.EventY_Multiplier * t5.ECMO_OCCUPANCY,1) as EventY_ECMO_OCCUPANCY,
												round(t1.EventY_Multiplier * t6.VENT_OCCUPANCY,1) as EventY_VENT_OCCUPANCY
										from
											(select ScenarioNameUnique, ModelType, Date, EventY_Multiplier from work.MODEL_FINAL) t1
											left join
											(select ScenarioNameUnique, ModelType, HOSPITAL_OCCUPANCY from work.Model_FINAL where PEAK_HOSPITAL_OCCUPANCY) t2
											on t1.ScenarioNameUnique=t2.ScenarioNameUnique and t1.ModelType=t2.ModelType
											left join
											(select ScenarioNameUnique, ModelType, ICU_OCCUPANCY from work.Model_FINAL where PEAK_ICU_OCCUPANCY) t3
											on t1.ScenarioNameUnique=t3.ScenarioNameUnique and t1.ModelType=t3.ModelType
											left join
											(select ScenarioNameUnique, ModelType, DIAL_OCCUPANCY from work.Model_FINAL where PEAK_DIAL_OCCUPANCY) t4
											on t1.ScenarioNameUnique=t4.ScenarioNameUnique and t1.ModelType=t4.ModelType
											left join
											(select ScenarioNameUnique, ModelType, ECMO_OCCUPANCY from work.Model_FINAL where PEAK_ECMO_OCCUPANCY) t5
											on t1.ScenarioNameUnique=t5.ScenarioNameUnique and t1.ModelType=t5.ModelType
											left join
											(select ScenarioNameUnique, ModelType, VENT_OCCUPANCY from work.Model_FINAL where PEAK_VENT_OCCUPANCY) t6
											on t1.ScenarioNameUnique=t6.ScenarioNameUnique and t1.ModelType=t6.ModelType
									) m2
								on m1.ScenarioNameUnique=m2.ScenarioNameUnique and m1.ModelType=m2.ModelType and m1.DATE=m2.DATE
							;
					QUIT;
				/* use proc datasets to apply labels to each column of output data table
					except INPUTS which is documented right after the %EasyRun definition
				 */
					PROC DATASETS LIB=WORK NOPRINT;
						MODIFY MODEL_FINAL;
							LABEL
								ADMIT_DATE = "Date of Admission"
								DATE = "Date of Infection"
								DAY = "Day of Pandemic"
								HOSP = "Newly Hospitalized"
								HOSPITAL_OCCUPANCY = "Hospital Census"
								MARKET_HOSP = "Regional Newly Hospitalized"
								MARKET_HOSPITAL_OCCUPANCY = "Regional Hospital Census"
								ICU = "Newly Hospitalized - ICU"
								ICU_OCCUPANCY = "Hospital Census - ICU"
								MARKET_ICU = "Regional Newly Hospitalized - ICU"
								MARKET_ICU_OCCUPANCY = "Regional Hospital Census - ICU"
								MedSurgOccupancy = "Hospital Medical and Surgical Census (non-ICU)"
								Market_MedSurg_Occupancy = "Regional Medical and Surgical Census (non-ICU)"
								VENT = "Newly Hospitalized - Ventilator"
								VENT_OCCUPANCY = "Hospital Census - Ventilator"
								MARKET_VENT = "Regional Newly Hospitalized - Ventilator"
								MARKET_VENT_OCCUPANCY = "Regional Hospital Census - Ventilator"
								DIAL = "Newly Hospitalized - Dialysis"
								DIAL_OCCUPANCY = "Hospital Census - Dialysis"
								MARKET_DIAL = "Regional Newly Hospitalized - Dialysis"
								MARKET_DIAL_OCCUPANCY = "Regional Hospital Census - Dialysis"
								ECMO = "Newly Hospitalized - ECMO"
								ECMO_OCCUPANCY = "Hospital Census - ECMO"
								MARKET_ECMO = "Regional Newly Hospitalized - ECMO"
								MARKET_ECMO_OCCUPANCY = "Regional Hospital Census - ECMO"
								Deceased_Today = "New Hospital Mortality"
								Fatality = "New Hospital Mortality"
								Total_Deaths = "Cumulative Hospital Mortality"
								Market_Deceased_Today = "New Regional Mortality"
								Market_Fatality = "New Regional Mortality"
								Market_Total_Deaths = "Cumulative Regional Mortality"
								N = "Region Population"
								S_N = "Current Susceptible Population"
								E_N = "Current Exposed Population"
								I_N = "Current Infected Population"
								R_N = "Current Recovered Population"
								NEWINFECTED = "Newly Infected Population"
								ModelType = "Model Type Used to Generate Scenario"
								SCALE = "Ratio of Previous Day Population to Current Day Population"
								ScenarioIndex = "Scenario ID: Order"
								ScenarioSource = "Scenario ID: Source (BATCH or UI)"
								ScenarioUser = "Scenario ID: User who created Scenario"
								ScenarioNameUnique = "Unique Scenario ID"
								Scenarioname = "Scenario Name Short"
								LOWER_HOSPITAL_OCCUPANCY="Lower Bound: Hospital Census"
								LOWER_ICU_OCCUPANCY="Lower Bound: Hospital Census - ICU"
								LOWER_VENT_OCCUPANCY="Lower Bound: Hospital Census - Ventilator"
								LOWER_ECMO_OCCUPANCY="Lower Bound: Hospital Census - ECMO"
								LOWER_DIAL_OCCUPANCY="Lower Bound: Hospital Census - Dialysis"
								UPPER_HOSPITAL_OCCUPANCY="Upper Bound: Hospital Census"
								UPPER_ICU_OCCUPANCY="Upper Bound: Hospital Census - ICU"
								UPPER_VENT_OCCUPANCY="Upper Bound: Hospital Census - Ventilator"
								UPPER_ECMO_OCCUPANCY="Upper Bound: Hospital Census - ECMO"
								UPPER_DIAL_OCCUPANCY="Upper Bound: Hospital Census - Dialysis"
								PEAK_HOSPITAL_OCCUPANCY = "Peak Starts: Hospital Census"
								PEAK_ICU_OCCUPANCY = "Peak Starts: Hospital Census - ICU"
								PEAK_VENT_OCCUPANCY = "Peak Starts: Hospital Census - Ventilator"
								PEAK_ECMO_OCCUPANCY = "Peak Starts: Hospital Census - ECMO"
								PEAK_DIAL_OCCUPANCY = "Peak Starts: Hospital Census - Dialysis"
								PEAK_I_N = "Peak Starts: Current Infected Population"
								PEAK_FATALITY = "Peak Starts: New Hospital Mortality"
								ISOChangeEvent = "Event labels for Dates of Change"
								EventY_HOSPITAL_OCCUPANCY = "Y for plotting ISOChangeEvent with HOSPITAL_OCCUPANCY"
								EventY_ICU_OCCUPANCY = "Y for plotting ISOChangeEvent with ICU_OCCUPANCY"
								EventY_VENT_OCCUPANCY = "Y for plotting ISOChangeEvent with VENT_OCCUPANCY"
								EventY_ECMO_OCCUPANCY = "Y for plotting ISOChangeEvent with ECMO_OCCUPANCY"
								EventY_DIAL_OCCUPANCY = "Y for plotting ISOChangeEvent with DIAL_OCCUPANCY"
								;
							MODIFY SCENARIOS;
							LABEL
								scope = "Source Macro for variable"
								name = "Name of the macro variable"
								offset = "Offset for long character macro variables (>200 characters)"
								value = "The value of macro variable name"
								ScenarioIndex = "Scenario ID: Order"
								ScenarioSource = "Scenario ID: Source (BATCH or UI)"
								ScenarioUser = "Scenario ID: User who created Scenario"
								ScenarioNameUnique = "Unique Scenario Name"
								Scenarioname = "Scenario Name Short"
								Stage = "INPUT for input variables - MODEL for all variables"
								;
							MODIFY INPUTS;
							LABEL
								ScenarioIndex = "Scenario ID: Order"
								ScenarioSource = "Scenario ID: Source (BATCH or UI)"
								ScenarioUser = "Scenario ID: User who created Scenario"
								ScenarioNameUnique = "Unique Scenario Name"
								Scenarioname = "Scenario Name Short"
								;

					RUN;
					QUIT;

                %IF &ScenarioSource = BATCH %THEN %DO;
                
                    PROC APPEND base=store.MODEL_FINAL data=work.MODEL_FINAL NOWARN FORCE; run;
                    PROC APPEND base=store.SCENARIOS data=work.SCENARIOS; run;
                    PROC APPEND base=store.INPUTS data=work.INPUTS; run;


                    PROC SQL;
                        drop table work.MODEL_FINAL;
                        drop table work.SCENARIOS;
                        drop table work.INPUTS;

                    QUIT;

                %END;

        %END;
        /*%ELSE %IF &PLOTS. = YES %THEN %DO;*/
        %ELSE %DO;
            %IF &ScenarioSource = BATCH %THEN %DO;
                PROC SQL; 
                    drop table work.MODEL_FINAL;
                    drop table work.SCENARIOS;
                    drop table work.INPUTS; 

                QUIT;
            %END;
        %END;
%mend;


