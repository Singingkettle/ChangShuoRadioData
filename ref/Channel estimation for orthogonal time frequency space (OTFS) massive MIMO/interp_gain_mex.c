/*
 * interp_gain_mex.c
 *
 * This file contains mex Gateway for interpolation with 
 * GNU Scientific Library interpolation functions.
 *
 * The system must have GNU Scientific library installed.
 *
 * Compilation:
 *
 *   mex interp_gain_mex.c -lgsl -lgslcblas -lm
 *
 * @author Jussi Salmi, Helsinki University of Technology, Radio Laboratory, SMARAD Center of Excellence
 * @date 2004/07/26

 */

#include <stdlib.h>
#include <stdio.h>
#include "mex.h"
#include <math.h>
#include <gsl/gsl_errno.h>
#include <gsl/gsl_spline.h>
#define LINEAR 1     /* for linear interpolation */
#define CUBIC_P 2    /* for cubic spline with periodic boundary conditions */
#define LUT 3        /* look-up table interpolation, finds nearest known point */
#define CUBIC 4      /* cubic spline with natural boundary conditions */
#define AKIMA 5      /* Non-rounded Akima spline with natural boundary conditions. */
#define AKIMA_P 6    /* Non-rounded Akima spline with periodic boundary conditions. */
                     /* Akima methods use the non-rounded corner algorithm of Wodicka. */


/**
 * This is the mex-function for GNU Scientific Library interpolation.
 *
 * Input arguments are:
 *
 * prhs[0] = xn - points where the values of yn are known (1-Dimensional vector)
 * prhs[1] = yn - function values of the points xn ( size [length(xn)][num of separate data sets])
 * prhs[2] = xi - points where yi values are evaluated (1-Dimensional vector)
 * prhs[3] = type - interpolation type used in calculations (integer)
 *
 * Output argument is 
 * plhs[0] = yi - output matrix of interpolated values (size [length(xi)][num of separate data sets])
 */
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
   double *xn, *yn, *xi, *yi, step; /* variables for input arguments */
   int i, ii, lut_i; /* running index variables */
   int nsize, isize, type, *yn_dims, num_elements, halfn; /* for the parameter sizes */
   gsl_interp_accel *accelerator; /* interpolation accelerator */
   gsl_spline *spline; /* interpolation object */

/* get the output dimensions */
   yn_dims = (int*)mxGetDimensions(prhs[1]);
/*   xi_dims = (int*)mxGetDimensions(prhs[2]);*/
   isize = mxGetNumberOfElements(prhs[2]); /* number of output points */ 

   nsize = yn_dims[0]; /* number of points for interpolation */
   num_elements = yn_dims[1]; /* number of separate interpolations */

/* taking inputs */
   xn = (double*)mxGetPr(prhs[0]);
   yn = (double*)mxGetPr(prhs[1]);
   xi = (double*)mxGetPr(prhs[2]);
   type = (int)mxGetScalar(prhs[3]);

   /* creates matrix for output */
   plhs[0] = (mxArray*) mxCreateDoubleMatrix(num_elements, isize, mxREAL);
   yi = (double*)mxGetPr(plhs[0]);

   accelerator = gsl_interp_accel_alloc();
   spline = gsl_spline_alloc(gsl_interp_cspline_periodic, nsize);
   
   /* look-up method */
   if (type == LUT) {
      halfn = (int)0.5*nsize;
      step = 0.5*fabs(*(xn+halfn)-*(xn+halfn+1));
      for (i=0; i<num_elements; i++) {
         for (ii=0; ii<isize; ii++) {
            lut_i = (int)gsl_interp_accel_find(accelerator, xn, nsize, xi[ii]+step);
            *(yi+i*isize+ii) = *(yn+i*nsize+lut_i);
         }
      }
   }

   /* choosing interpolation method */
   else {
      if (type == LINEAR) {
         spline = gsl_spline_alloc(gsl_interp_linear, nsize);
      }
      else if (type == CUBIC_P) {
         spline = gsl_spline_alloc(gsl_interp_cspline_periodic, nsize);
      }
      else if (type == CUBIC) {
         spline = gsl_spline_alloc(gsl_interp_cspline, nsize);
      }
      else if (type == AKIMA) {
         spline = gsl_spline_alloc(gsl_interp_akima, nsize);
      }
      else if (type == AKIMA_P) {
         spline = gsl_spline_alloc(gsl_interp_akima_periodic, nsize);
      }
      else
         mexErrMsgTxt("interpolate_mex error: Interpolation type undefined\n");

      /* interpolating values */
      for (i=0; i<num_elements; i++) {
         gsl_spline_init(spline, xn, (yn+i*nsize), nsize);
         for (ii=0; ii<isize; ii++)
            *(yi+i*isize+ii) = gsl_spline_eval(spline, xi[ii], accelerator);
      }
   }
   gsl_spline_free(spline);
   gsl_interp_accel_free(accelerator);
}
