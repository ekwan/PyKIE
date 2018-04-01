/*

    MQF - Multiple Quantum Filtered 1D Fluorine Spectra

    This sequence gives antiphase peaks for the one-bond 13C satellites in 19F spectra.

    Notes:
    - Phase cycling removes the natural 12C peak.
    - Place the transmitter and decoupler offsets on resonance.
    - 1H decoupling should be used (WALTZ-16).
    - 13C decoupling should not be used.
    - nt should be a multiple of 2 and ideally a multiple of 32.

    Eugene Kwan and Harrison Besser, Harvard University, March 2018

*/

#include <standard.h>
#include <chempack.h>

// phase table

static int ph1[32] = {0,2,0,2, 1,3,1,3,  0,2,0,2, 1,3,1,3,  0,2,0,2, 1,3,1,3,  0,2,0,2, 1,3,1,3},  // phase of first 19F 90
           ph2[32] = {0,0,0,0, 0,0,0,0,  1,1,1,1, 1,1,1,1,  2,2,2,2, 2,2,2,2,  3,3,3,3, 3,3,3,3},  // phase of 13C 180
           ph3[32] = {0,0,2,2, 1,1,3,3,  0,0,2,2, 1,1,3,3,  0,0,2,2, 1,1,3,3,  0,0,2,2, 1,1,3,3},  // phase of second 19F 90
           ph4[32] = {0,2,2,0, 2,0,0,2,  2,0,0,2, 0,2,2,0,  0,2,2,0, 2,0,0,2,  2,0,0,2, 0,2,2,0};  // receiver phase

pulsesequence()

{
    double  j1cf = getval("j1cf"),                           // the size of the one-bond carbon-fluorine coupling constant in Hz
            tau = 1 / (2*j1cf),                              // the duration of the magnetization transfer delay in seconds

            pwx = getval("pwx"),                             // the duration of the 90 degree pulses on carbon in us
            pwxlvl = getval("pwxlvl"),                       // the power level of the 90 degree pulses on carbon in dB

            invlvl = getval("invlvl"),                       // the power level of the fluorine inversion pulse in dB
            invwidth = getval("invwidth");                   // the length of the fluorine inversion pulse in us

    char    invshape[MAXSTR];                                // name of the inversion pulse shape
    
    getstr("invshape", invshape);

    // setup phase tables
    settable(t1, 32 , ph1);
    settable(t2, 32 , ph2);
    settable(t3, 32 , ph3);
    settable(t4, 32 , ph4);

    getelem(t1, ct, v1);
    getelem(t2, ct, v2);
    getelem(t3, ct, v3);
    getelem(t4, ct, oph);

    // delay period
    status(A);
    decpower(dpwr);
    delay(d1);

    // pulsing period
    status(B);
    obspower(tpwr);
    rgpulse(pw, zero, rof1, rof2);
    delay(tau);
    
    // transfer to MQC
    decpower(pwxlvl);
    decrgpulse(pwx, v1, rof1, rof2);

    // refocus dead time
    decpower(invlvl);
    decshaped_pulse(invshape, invwidth, v2, rof1, rof2);
    
    // transfer back to antiphase
    decpower(pwxlvl);
    decrgpulse(pwx, v3, rof1, rof2);
    decpower(dpwr);

    // acquire
    status(C);
}
