# usage: awk -f makeBIP.awk bip.dat ref_pwr ref_pw90
# ref_pwr in dB, ref_pw90 in us
BEGIN {
    # spectrometer frequency in MHz
    spectrometer_frequency = 125.0

    # amplitude of the pulse
    amplitude = 1023.0

    # check number of command line arguments
    if ( ARGC != 4 ) {
        print "usage: awk -f makeBIP.awk bip.dat ref_pwr ref_pw90"
        exit_code = 1
        exit
    }

    # get calibration data
    ref_pwr = ARGV[2]
    ref_pw90 = ARGV[3]
    B1_0 = 1/(4*ref_pw90*1e-6)
    
    # parse BIP filename
    nargs = split(ARGV[1],fields,"[-.]")
    if ( nargs != 4 ) {
        print "this does not seem to be a valid BIP data file"
        exit_code = 1
        exit
    }

    # calculate powers and times
    unitless_bandwidth = fields[1] / 100.0
    unitless_inhomogeneity_compensation = fields[2] / 100.0
    bip_equivalent_rotation = fields[3] + 0.0

    actual_bandwidth_kHz = unitless_bandwidth * B1_0 / 1000.0
    actual_bandwidth_ppm = unitless_bandwidth * B1_0 / spectrometer_frequency

    actual_inhomogeneity_compensation_kHz = unitless_inhomogeneity_compensation * B1_0 / 1000.0
    actual_inhomogeneity_compensation_ppm = unitless_inhomogeneity_compensation * B1_0 / spectrometer_frequency

    bipwidth = ref_pw90 * bip_equivalent_rotation / 90.0
    nsteps = sprintf("%d", 2.0 * bipwidth + 0.5) + 0

    # print header
    print  "# ========== Broadband Inversion Pulse (BIP) =========="
    printf "# ref_pwr         =     %6.0f dB\n", ref_pwr
    printf "# ref_pw90        =     %6.2f us\n", ref_pw90
    printf "# spectr. freq.   =     %6.2f MHz\n", spectrometer_frequency
    printf "# B1_0            =     %6.2f kHz = %.1f ppm\n", B1_0/1000.0, B1_0 / spectrometer_frequency
    #printf "# BIP bandwidth   = +/- %6.2f kHz = %.1f ppm\n", actual_bandwidth_kHz, actual_bandwidth_ppm
    printf "# BIP bandwidth   =     %6.2f kHz = %.1f ppm\n", 2*actual_bandwidth_kHz, 2*actual_bandwidth_ppm
    printf "# inhomog. comp.  = +/- %6.2f kHz = %.1f ppm\n", actual_inhomogeneity_compensation_kHz,  actual_inhomogeneity_compensation_ppm
    printf "# BIP length      =     %6.1f us\n", bipwidth
    printf "# number of steps =     %6d steps\n", nsteps
    printf "# time/step       =     %6.2f us\n", bipwidth/nsteps
    print  "# ====================================================="
}

NR == FNR {
    trimmed = trim($0)
    # ignore blank lines and those starting with a # sign
    if ( length(trimmed) != 0 && substr(trimmed,0,1) != "#" ) {
            if (trimmed == "end")
                exit
            coeff_count++
            boundaries[coeff_count] = $1 + 0.0

            # set coefficients[coeff_count, 0] = zeroth-order term
            # [coeff_count, 1] = first-order term, etc.
            for (i=2; i <= 5; i++)
                coefficients[coeff_count,i-2] = $i + 0.0
        }
}

END {
# terminate on error
if ( exit_code != 0 )
    exit exit_code

# print polynomial endpoints
print "#"
print "# polynomial smoothness (discontinuity should be less than 1 degree)"
for (i=2; i <= coeff_count; i++) {
    value1 = coefficients[i-1,0] + coefficients[i-1,1] * boundaries[i-1] + coefficients[i-1,2] * boundaries[i-1]^2 + coefficients[i-1,3] * boundaries[i-1]^3
    value2 = coefficients[i,0] + coefficients[i,1] * boundaries[i-1] + coefficients[i,2] * boundaries[i-1]^2 + coefficients[i,3] * boundaries[i-1]^3
    printf "# %d-%d : %7.4f : %7.2f %7.2f   :   discontinuity = %7.4f degrees\n", i-1, i, boundaries[i-1], value1, value2, value2-value1
}

# calculate BIP
print "#"
print "# -----------------------------------------------------"
print "#  phase (degrees)   amplitude   duration    gate"
print "# -----------------------------------------------------"


print "tau,phase,a0,a1,a2,a3" > "bip.csv"
for (i=1; i <= nsteps; i++) {
    tau = -10+20*i/(nsteps+1)
    phase = eval(tau)
    
    # get coefficients
    a[0] = -1
    a[1] = -1
    a[2] = -1
    a[3] = -1
    for (k=1; k <= coeff_count; k++) {
        #print abs(tau), boundaries[k], abs(tau) < boundaries[k]
        if ( abs(tau) < boundaries[k] ) {
                for (l=0; l <= 3; l++)
                    a[l] = coefficients[k,l]
                break
            }
    }
    #print a[0], a[1], a[2], a[3]

    printf "     %7.2f           %7.2f     1.0         1\n", mod360(phase), amplitude
    printf "%.4f,%.4f,%.5f,%.5f,%.5f,%.5f\n", tau, phase,a[0],a[1],a[2],a[3] >> "bip.csv"
}

}

# evaluate cubic
function eval(tau,   a,i,j,t) {
    # get coefficients
    for (i=1; i <= coeff_count; i++) {
        if ( abs(tau) < boundaries[i] ) {
                for (j=0; j <= 3; j++)
                    a[j] = coefficients[i,j]
                break
            }
    }

    # calculate polynomial
    t = abs(tau)
    return a[0] + a[1]*t + a[2]*t^2 + a[3]*t^3
}

# absolute value
function abs(v) {return v < 0 ? -v : v}

# convert anything outside [0...360] to inside it
function mod360(phi) { return phi > 0 ? phi % 360 : abs((phi % 360) + 360) }

function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
function trim(s) { return rtrim(ltrim(s)); }
