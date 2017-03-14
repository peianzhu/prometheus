#!/usr/bin/perl
use strict;
use Getopt::Long;
use DateTime;
use Data::Dumper;

#This file name to analyze
my $filename;
#The number of top tasks to print out
my $topN=0;
#Print out the top tasks in csv form
my $csv=0;
#Show the weekends for debugging
my $showWeekend=0;
#Print the output in CSV format
my $csvout=0;
#Print out the moving average data
my $mave=0;

GetOptions('file|f=s' => \$filename, 'top=i' => \$topN, 'csv' => \$csv, 
    'sw|showweekend' => \$showWeekend, 'csvout' => \$csvout, 'mave' => \$mave );

#Giant map of task normailizations
my $taskSwitch = {

    "rel. mgmt" => "rel mgmt",
    "rel mgmt." => "rel mgmt",

    "admin-recuiting" => "admin-recruiting",
    "admin social" => "admin-social",
    "admin-interviewing" => "admin-recruiting",
    "admin-interview" => "admin-recruiting",
    "admin interview" => "admin-recruiting",
    "admin interviews" => "admin-recruiting",
    "admin-hiring" => "admin-recruiting",
    "recruiting" => "admin-recruiting",
    "admin-inteview" => "admin-recruiting",
    "admin-inteviews" => "admin-recruiting",
    "admin-interviews" => "admin-recruiting",
    "admin-recruting" => "admin-recruiting",

    "admin-personal" => "admin-personal day",
    "admin-holidy" => "admin-holiday",
    "vacation" => "admin-vacation",
    "admin vacation" => "admin-vacation",

    "meeting" => "admin-meeting",

    "change mgmt" => "rel mgmt",
    "one blackrock" => "one blackrock site",
    "stellent" => "stellent decom",
    "aalddin wealth" => "aladdin wealth",

    "hackthon" => "hackathon",

    "client site" => "client sites",
    "acs" => "client sites",
    "das" => "data platform",
    "dal" => "data platform",
    "data" => "data platform",

    "internet" => "intranet",
    "intranet problems" => "intranet",
    "intranet rework" => "intranet",
    "intranet/open cms" => "intranet",
    "open cms" => "intranet",

    "admin-discussions" => "admin-discussion",
    "admin-disucssion" => "admin-discussion",
    "admin-conversation" => "admin-discussion",
    "technical advice" => "admin-discussion",

    "dmz review" => "dmz",
    "ordergapworksheet" => "order gap worksheet",

    "planning/mgmt" => "planning-mgmt",
    "planning mgmt" => "planning-mgmt",
    "planning-mbmt" => "planning-mgmt",
    "plannin-mgmt" => "planning-mgmt",
    "plannning-mgmt" => "planning-mgmt",
    "planning mgmt" => "planning-mgmt",
    "planning mmgt" => "planning-mgmt",
    "planinng mgmt" => "planning-mgmt",
    "planningmgmt" => "planning-mgmt",
    "planinng-mgmt" => "planning-mgmt",
    "planning-management" => "planning-mgmt",
    "admin-planning" => "planning-mgmt",
    "planning-mmgt" => "planning-mgmt",
    "plannin mgmt" => "planning-mgmt",

    "admin-bus. development" => "admin-business-dev",
    "admin-business devl." => "admin-business-dev",
    "admin-business dev." => "admin-business-dev",

    "admin general" => "admin-general",
    "adminn-general" => "admin-general",
    "admingeneral" => "admin-general",
    "gmbs" => "admin-general",

    "admin-illness" => "admin-sickday",
    "admin-sick" => "admin-sickday",
    "admin-sick day" => "admin-sickday",

    "galilleo" => "galileo",

    "time accounting" => "admin-timesheets",

    "futureadvisor" => "future advisor",

    "apg-innovation" => "innovation",

    "sf innovation" => "sf innovates",

    "sam & mi6" => "sam mi6",
    "sam" => "sam mi6",
    "wif" => "women in focus",

    "core platflrom" => "core platform",
    "core platfrom" => "core platform",
    "core web platform" => "core platform",
    "core sofware" => "core software",
    "revolutions" => "aladdin-revolutions",
    "aladdin revolutions" => "aladdin-revolutions",
    "suport" => "support",
    "admin-support" => "support",
    "gls" => "core platform",
    "user platform" => "core platform",
    "fact sheets" => "factsheets",
    "sam/mi6" => "sam mi6",
    "jbpm" => "bpm",
    "serpet" => "serpent",
    "on webster" => "one webster",
    "gpwizard" => "gp wizard",
    "snapshot" => "gp snapshot",
    "cash" => "client sites",
    "advisor" => "advisor site",
   
    "arb" => "architecture board",
    "architcture board" => "architecture board",

    "av" => "aladdinview",
    "aladdin-view" => "aladdinview",
    "aladdin view" => "aladdinview",

    "30 min workout" => "30 minute workout",
    "30 min review" => "30 minute workout",
    "30 minute wrkout" => "30 minute workout",
    "30 minute review" => "30 minute workout",

    "onboarding" => "on boarding",
    "on-boarding" => "on boarding",
    "bgi onboarding" => "on boarding",
};

#The cheesy CSV line parser I wrote on a plan
sub parseLine {
    my $line = shift;
    #print "$line";
    my $x = 0;
    my $tokens;
    while ( $line=~m/^([^,"]+)(?:([,])(.*)|$)/ || $line=~m/^"(.*?)"(?:(?:(,)(.*))|$)/ ) {
        my $match = $1;
        my $sep = $2;
        $line = $3;
        $match =~ s/""/"/g;
        #print "$x=$match SEP=$sep REST=$line\n";
        push @{$tokens}, $match;
        $x++;
        if ( $x > 100 ) {
            die "Something went wrong with CSV line parsing!";
        }
    }
    return $tokens;
}

sub normalizeTaskName {
    my $taskName = shift;
    $taskName = lc($taskName);
    $taskName =~ s/\s+$//;
    $taskName =~ s/adming-/admin/;
    if ( $taskSwitch->{$taskName} ) {
        $taskName = $taskSwitch->{$taskName};
    }
    return $taskName;
}

sub getTimeInMins {
    my $minsec = shift;
    my $mins = 0;
    if ( $minsec =~ m/(\d+):(\d+)\s+(AM|PM)/ ) {
        my $hour = $1;
        my $min = $2;
        my $ampm = $3;
        $mins = (($hour eq '12' && $ampm eq 'AM' ) ? 0 : ($hour * 60)) + $min + (( $ampm =~ m/PM/ && $hour < 12 ) ? 12*60 : 0 );
    } elsif ( $minsec =~ m/(\d+):(\d+)/ ) {
        $mins = $1 * 60 + $2;
    }
    return $mins;
}

sub isWeekend {
    my $dt = getDateTime(shift);
    if ( $dt ) {
        return $dt->day_of_week() > 5;
    } else {
        return 0;
    }
}

sub isMonday {
    my $dt = getDateTime(shift);
    if ( $dt ) {
        return $dt->day_of_week() == 1;
    } else {
        return 0;
    }
}

#Return the week of the year in a format like "2006.13"
sub getWeekKey {
    my $dt = getDateTime(shift);
    if ( $dt ) {
        return $dt->year() +  ( $dt->week_number() / 100 ) ;
    } else {
        return 'N/A';
    }
}


#Convert the string date format from the csv files into a 
#Perl DateTime object
sub getDateTime {
    my $date = shift;
    if ( $date =~ m[(\d{1,2})/(\d{1,2})/(\d{2})] ) {
        my $month = $1;
        my $day = $2;
        my $year = $3;
        if ( $month == 0 || $day == 0 ) {
            return 0;
        }
        return DateTime->new( month => $month, day => $day, year => 2000+$year);
    } else {
        return undef;
    }
}


my $FH; #File handle

open $FH, "<", $filename or die "Could not open file for reading: $filename";

#Shitty global variables that mean I am a shitt programmer
my $taskNames;

my $elapsedTimeIndex;
my $startTimeIndex;
my $endTimeIndex;
my $weekOfIndex;
my $dateIndex;
my $breakTimeIndex = -1;

my $totalElapsedTime=0;

my $holidays;
my $vacationdays;
my $workdays;
my $sickdays;
my $jurydutydays;
my $personaldays;
my $tasksperday;
my $hoursperday;
my $startperday;
my $finishperday;
my $noworkday;
my $offdays;
my $nonTravelPastMidnight;
my $startTimeMin;
my $endTimeMax;
#Hash that has dates where I worked 'late' (i.e. past 8 pm)
my $lateNights;
#Weekly data hash ref
#Data will be like this:
#$weeklyData->{<weekKey>}
#    ->{  
#         'elapsedMins' => <number-mins>,
#         'mondaydate' => <dateOfMonday>
#         'fulldays' => {
#               "<date>" => 1,
#          },
#         'offdays' => {
#               "<date>" => 1,
#          },
#         'dayworktotal' => {
#               "<date>" => <number-mins>,
#          }
#      }
my $weeklyData;

#The main "read" loop to analyze the CSV file
for my $line ( <$FH> ) {
    my $tokens = parseLine($line);
    #Parse the header to get the indexes
    if ( $line =~ m/Task,SubTask/ ) {
        my $i = 0;
        for my $colName ( @{$tokens} ) {
            if ( $colName =~ m/Elapsed Time/ ) {
                $elapsedTimeIndex = $i;
            } elsif ( $colName =~ m/Start/ ) {
                $startTimeIndex = $i;
            } elsif ( $colName =~ m/End/ ) {
                $endTimeIndex = $i;
            } elsif ( $colName =~ m/Week Of/ ) {
                $weekOfIndex = $i;
            } elsif ( $colName =~ m/Date/ ) {
                $dateIndex = $i;
            } elsif ( $colName =~ m/Break Time/ ) {
                $breakTimeIndex = $i;
            }
            $i++;
        } 
    #Parse the other lines
    } else {
        my $taskName = normalizeTaskName($tokens->[0]);
        my $elapsedMins = getTimeInMins($tokens->[$elapsedTimeIndex]);
        my $date = $tokens->[$dateIndex];
        my $start = $tokens->[$startTimeIndex];
        my $end = $tokens->[$endTimeIndex];
        my $weekKey = getWeekKey($date);
        if ( $taskName =~ m/admin-vacation/  ) {
            #Need to find better partial vacation handling
            $vacationdays->{$date}=1;
            $offdays->{$date}=1;
            $weeklyData->{$weekKey}->{"offdays"}->{$date}=1;
        } elsif ( $taskName =~ m/admin-holiday/ ) {
            $holidays->{$date}=1;
            $offdays->{$date}=1;
            $weeklyData->{$weekKey}->{"offdays"}->{$date}=1;
        } elsif ( $taskName =~ m/admin-sickday/ ) {
            $sickdays->{$date}=1;
            $offdays->{$date}=1;
            $weeklyData->{$weekKey}->{"offdays"}->{$date}=1;
        } elsif ( $taskName =~ m/admin-jury duty/ ) {
            $jurydutydays->{$date}=1;
            $offdays->{$date}=1;
            $weeklyData->{$weekKey}->{"offdays"}->{$date}=1;
        } elsif ( $taskName =~ m/admin-personal day/ ) {
            $personaldays->{$date}=1;
            $offdays->{$date}=1;
            $weeklyData->{$weekKey}->{"offdays"}->{$date}=1;
        } elsif ( $taskName =~ m/no work/ || $taskName =~ m/nothing/ ) {
            $noworkday->{$date}=1;
            $offdays->{$date}=1;
            $weeklyData->{$weekKey}->{"offdays"}->{$date}=1;
        } else {
            $taskNames->{$taskName}->{count}++;
            $taskNames->{$taskName}->{total}+=$elapsedMins;
            $workdays->{$date}=1;
            $tasksperday->{$date}++;
            $hoursperday->{$date}+=$elapsedMins;
            $totalElapsedTime+=$elapsedMins;

            #Keep track of that weekly data
            $weeklyData->{$weekKey}->{"elapsedMins"}+=$elapsedMins;
            $weeklyData->{$weekKey}->{"dayworktotal"}->{$date}+=$elapsedMins;

            #Keep track of days where I worked past midnight...this is shady...
            if ( $taskName !~ m/admin-travel/ && ( $start =~ m/12:00 AM/ || $start =~ m/12:15 AM/ ) ) {
                $nonTravelPastMidnight++;
            }
            #Keep track of the starting time in minutes, but only if it is after 4 AM 
            #this will eliminate weird days where I am traveling or working round the clock
            my $startMins = getTimeInMins($start);
            if ( $startMins > 4*60 ) {
                if ( ! $startTimeMin->{$date} || $startMins < $startTimeMin->{$date} ) {
                    $startTimeMin->{$date} = $startMins;
                }
            }
            my $endMins = getTimeInMins($end);
            my $breakMins = $breakTimeIndex < 0 ? 0 : getTimeInMins($tokens->[$breakTimeIndex]);

            #Only count end times greater than 3 PM
            #Also, don't count end times where the break time is greater than 2 hours.  
            #Typically a 1 off home meeting
            #However, won't igore double meetings at home
            if ( $endMins > 15*60 && $breakMins < 2 * 60 ) {
                if ( ! $endTimeMax->{$date} || $endMins > $endTimeMax->{$date} ) {
                    $endTimeMax->{$date} = $endMins;
                }
            }
            #Find those late nights...
            if ( $endMins > 20*60 ) {
                $lateNights->{$date} = 1;
            }
        }

        #Find those mondays...
        if ( isMonday($date) && ! defined $weeklyData->{$weekKey}->{"mondaydate"} ) {
           $weeklyData->{$weekKey}->{"mondaydate"}=$date;
        }
    }
}

close $FH; #close the file handle

#Sort the tasks in order from most time spent to least
my $x= 1;
my $otherTotal=0;
my $otherCount=0;
if ( !$mave ) {
    for my $key ( sort { $taskNames->{$b}->{total} <=> $taskNames->{$a}->{total} } keys %{$taskNames} ) {
        if ( $topN == 0  || $x <= $topN ) {
            if ( !$csvout ) {
                if ( ! $csv ) {
                    printf "%-2i %-25s%5i%10i%7.2f%%\n", 
                        $x, $key, $taskNames->{$key}->{count}, $taskNames->{$key}->{total}, 
                        $taskNames->{$key}->{total}/$totalElapsedTime * 100;
                } else {
                    printf "%i,%s,%0.2f%%\n", 
                        $x, $key, $taskNames->{$key}->{total}/$totalElapsedTime * 100;
                }
            }
        } elsif ( $topN > 0 ) {
            $otherTotal += $taskNames->{$key}->{total};
            $otherCount += $taskNames->{$key}->{count};
        }
        $x++;
    }
}

#Calculate the totals for the 'other' catch all bucket of high level tasks
if ( $otherTotal > 0 ) {
    if ( ! $csvout ) {
        if ( ! $csv ) {
            printf "%-2i %-25s%5i%10i%7.2f%%\n", 
                $topN + 1, "Other", $otherCount, $otherTotal,
                $otherTotal/$totalElapsedTime * 100;
        } else {
            printf "%i,%s,%0.2f%%\n", 
                $topN + 1, "Other", $otherTotal/$totalElapsedTime * 100;
        }
    }
}

#Find the average number of tasks worked on a given day, and the max
my $maxTaskCount = 0;
my $maxTaskDate = 0;
my $taskPerDayTotal = 0;
for my $date ( keys %{ $tasksperday } ) {
   my $daycount = $tasksperday->{$date}; 
   $taskPerDayTotal += $daycount;
    if ( $daycount > $maxTaskCount ) {
        $maxTaskCount = $daycount;
        $maxTaskDate = $date;
    }
}

my $daysworked = scalar keys %{$workdays};

my $fulldaysworked = 0;
my $fulldaystotal;
my $weekendDaysWorked = 0;
my $offDaysWorked = 0;
my $maxElapsedDayTime = 0;
my $maxElapsedDay = '';
my $longerThan12 = 0;
my $avgStartTime = 0;
my $avgStartTimeCount = 0;
my $avgEndTime = 0;
my $avgEndTimeCount = 0;
my $latenightsworked = 0;

#Find the number of 'full' days worked (greater than 6 hours)
for my $date ( keys %{ $hoursperday } ) {
    my $elapsed = $hoursperday->{$date};
    if ( $elapsed > $maxElapsedDayTime ) {
        $maxElapsedDayTime = $elapsed;
        $maxElapsedDay = $date;
    } 
    if ( $elapsed > 12*60 ) {
        $longerThan12++;
    }
    if ( $elapsed > 6*60 ) {
        $fulldaysworked++;
        $fulldaystotal += $elapsed;

        if ( $lateNights->{$date} ) {
            $latenightsworked++;
        }

        my $weekKey = getWeekKey($date);
        $weeklyData->{$weekKey}->{"fulldays"}->{$date}=1;

        #Also only keep track of start time on these days
        if ( $startTimeMin->{$date} ) {
            $avgStartTime += $startTimeMin->{$date};
            $avgStartTimeCount++;
        }
        #Only keep track of end time on these days...
        if ( $endTimeMax->{$date} ) {
            $avgEndTime += $endTimeMax->{$date};
            $avgEndTimeCount++;
        }
    } else {
        if ( isWeekend($date) ) {
            $weekendDaysWorked++;
            if ( $showWeekend ) {
                print "Worked weekend day: $date\n";
            }
        } else {
            if ( $offdays->{$date} ) {
                $offDaysWorked++;
            } else {
            }
        }
    }
}

#print Data::Dumper->Dump([$weeklyData]);

#Find the average start time

if ( $mave ) {
    #Sort the work week
    for my $weekKey ( sort { $a <=> $b } keys %{$weeklyData} ) {
        #Calculate the prorated work days
        my $weekFullDayCount = defined ($weeklyData->{$weekKey}->{fulldays}) ? 
            scalar keys %{ $weeklyData->{$weekKey}->{fulldays} } : 0;

        my $weekOffDayCount = defined ($weeklyData->{$weekKey}->{offdays}) ? 
            scalar keys %{ $weeklyData->{$weekKey}->{offdays} } : 0;

###        if ( $weekFullDayCount + $weekOffDayCount < 5 ) {
###            printf "%s Mon: %s Elapsed: %i Full Count: %i Off Count: %i\n", 
###                $weekKey, 
###                $weeklyData->{$weekKey}->{mondaydate}, 
###                $weeklyData->{$weekKey}->{elapsedMins}, 
###                $weekFullDayCount,
###                $weekOffDayCount;
###        }
        printf "%s,%s,%3.2f,%i,%i\n",
            $weekKey, 
            $weeklyData->{$weekKey}->{mondaydate}, 
            $weeklyData->{$weekKey}->{elapsedMins}/60, 
            $weekFullDayCount,
            $weekOffDayCount;

    }
} else {
   if ( $csvout ) {
   
       ( my $year = $filename ) =~ s/TS_(\d{4}).csv/$1/;
   
       printf "%s,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%i,%s,%.2f,%s,%i:%02i,%i:%02i,%i,%i,%i,%i,%i,%i,%i,%i,%i,%i,%i,%i,%i\n", 
           $year,
           $totalElapsedTime, 
           (($totalElapsedTime)/$daysworked)/60, 
           (($totalElapsedTime)/$daysworked)/12,
           (($fulldaystotal)/$fulldaysworked)/60, 
           (($fulldaystotal)/$fulldaysworked)/12,
           ($taskPerDayTotal)/$daysworked,
           $maxTaskCount,
           $maxTaskDate,
           $maxElapsedDayTime/60,
           $maxElapsedDay,
           ($avgStartTime/$avgStartTimeCount)/60, ($avgStartTime/$avgStartTimeCount)%60,
           ($avgEndTime/$avgEndTimeCount)/60, ($avgEndTime/$avgEndTimeCount)%60,
           scalar keys %{$workdays},
           $fulldaysworked,
           $weekendDaysWorked,
           $offDaysWorked,
           $nonTravelPastMidnight,
           $longerThan12,
           $latenightsworked,
           scalar keys %{$holidays},
           scalar keys %{$sickdays},
           scalar keys %{$jurydutydays},
           scalar keys %{$personaldays},
           scalar keys %{$noworkday},
           scalar keys %{$vacationdays};
   } else {
   
       print '=' x 50 , "\n";
       printf "Total elapsed mins: %i\n", $totalElapsedTime;
       printf "Average work day in hours: %5.2f  (Weekly: %5.2f)\n", (($totalElapsedTime)/$daysworked)/60, (($totalElapsedTime)/$daysworked)/12;
       printf "Average full work day in hours: %5.2f  (Weekly: %5.2f)\n", (($fulldaystotal)/$fulldaysworked)/60, (($fulldaystotal)/$fulldaysworked)/12;
       printf "Average tasks per day: %5.2f\n", ($taskPerDayTotal)/$daysworked;
       printf "Max tasks in a given day %i on %s\n", $maxTaskCount, $maxTaskDate;
       print "\n";
       printf "Longest day worked %4.2f on %s\n", $maxElapsedDayTime/60, $maxElapsedDay;
       printf "Average start time %i:%02i\n", ($avgStartTime/$avgStartTimeCount)/60, ($avgStartTime/$avgStartTimeCount)%60;
       printf "Average end time %i:%02i\n", ($avgEndTime/$avgEndTimeCount)/60, ($avgEndTime/$avgEndTimeCount)%60;
       print "\n";
       printf "Total work days: %i\n", scalar keys %{$workdays};
       printf "Total full work days: %i\n", $fulldaysworked;
       printf "Weekend days worked: %i\n", $weekendDaysWorked;
       printf "Off days worked: %i\n", $offDaysWorked;
       printf "Days past midnight worked: %i\n", $nonTravelPastMidnight;
       printf "Number days longer than 12 hour: %i\n", $longerThan12;
       printf "Number late nights worked: %i\n", $latenightsworked;
       print "\n";
       printf "Total holidays: %i\n", scalar keys %{$holidays};
       printf "Total sick days: %i\n", scalar keys %{$sickdays};
       printf "Total jury days: %i\n", scalar keys %{$jurydutydays};
       printf "Total personal days: %i\n", scalar keys %{$personaldays};
       printf "No work days: %i\n", scalar keys %{$noworkday};
       printf "Total vacation days (full or part): %i\n", scalar keys %{$vacationdays};
   
   }
}

