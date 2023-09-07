#!/bin/bash

# Set the base paths
BASE_PATH="/home/pradeep/WRF_SHELL_SCRIP_TEST/"
WPS_DIR="$BASE_PATH/NEW-WRF/FIRST_METHOD/WPS"
OUTPUT_DIR="$BASE_PATH/MET_OUT_PUT/"
FNL_PATH="$BASE_PATH/FNL_DATA/"

# Specify the years
years=("2007" "2008")

# Specify the months and days for both runs
months=("06" "07")
start_days=("25" "01")
end_days=("30" "05")

# Create a directory for log files
LOG_DIR="$BASE_PATH/logs"
mkdir -p "$LOG_DIR"

# Function to print a progress message
print_progress() {
    current_year=$((current_year + 1))
    echo "Year $year processing complete ($current_year of $total_years)"
}

# Loop through the years
for year in "${years[@]}"; do
    for i in "${!months[@]}"; do
        month="${months[$i]}"
        start_day="${start_days[$i]}"
        end_day="${end_days[$i]}"

        echo "Processing year: $year, Month: $month, Days: $start_day to $end_day"
        
        # Set the start date and time
        start_date="${year}-${month}-${start_day}_00:00:00"
        echo "Start date: $start_date"

        # Set the end date and time
        end_date="${year}-${month}-${end_day}_00:00:00"
        echo "End date: $end_date"

        # Update the start and end dates in namelist.wps using awk
        awk -v sdate="$start_date" -v edate="$end_date" '
        /start_date/ {$0 = " start_date = \x27" sdate "\x27,"}
        /end_date/ {$0 = " end_date = \x27" edate "\x27,"}
        {print}
        ' "$WPS_DIR/namelist.wps" > "$WPS_DIR/namelist_tmp.wps"

        # Replace the original namelist.wps with the updated file
        mv "$WPS_DIR/namelist_tmp.wps" "$WPS_DIR/namelist.wps"

        # Print the contents of namelist.wps after updates
        echo "Contents of namelist.wps after updates:"
        cat "$WPS_DIR/namelist.wps"

        # Run geogrid.exe with logging
        echo "Running geogrid..."
        GEOGRID_LOG="$LOG_DIR/geogrid_${year}_${month}.log"
        cd "$WPS_DIR"
        ./geogrid.exe > "$GEOGRID_LOG" 2>&1
        tail -n 1 "$GEOGRID_LOG"  # Print the last line of the geogrid log

        # Update the FNL data path for the current year
        FNL_PATH="${BASE_PATH}FNL_DATA/${year}/"

        # Print the FNL data path
        echo "FNL_PATH: $FNL_PATH"

        # Run link_grib.csh script to link specific FNL grib files
        echo "Creating symbolic links for FNL grib files..."
        cd "$WPS_DIR"
        ./link_grib.csh "${FNL_PATH}fnl_${year}*" > "$LOG_DIR/link_grib_${year}_${month}.log" 2>&1
        tail -n 1 "$LOG_DIR/link_grib_${year}_${month}.log"  # Print the last line of the link_grib log

        # Run ungrib.exe with logging
        echo "Running ungrib..."
        UNGRIB_LOG="$LOG_DIR/ungrib_${year}_${month}.log"
        ./ungrib.exe > "$UNGRIB_LOG" 2>&1
        tail -n 1 "$UNGRIB_LOG"  # Print the last line of the ungrib log

        # Run metgrid.exe with logging
        echo "Running metgrid..."
        METGRID_LOG="$LOG_DIR/metgrid_${year}_${month}.log"
        ./metgrid.exe > "$METGRID_LOG" 2>&1
        tail -n 1 "$METGRID_LOG"  # Print the last line of the metgrid log

        # Move the metgrid output to the output directory
        echo "Moving metgrid output..."
        mv met_em* "$OUTPUT_DIR/"

        # Clean up ungrib output
        echo "Cleaning up..."
        rm -f GRIBFILE.*
        rm -f FILE*

        # Print progress
        print_progress

        echo "Year $year, Month $month processing complete"
    done
done

# Create a final log file
FINAL_LOG="$LOG_DIR/final_script.log"
