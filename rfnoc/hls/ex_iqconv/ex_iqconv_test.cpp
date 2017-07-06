//
//    rfnoc-hls-neuralnet: Vivado HLS code for neural-net building blocks
//
//    Copyright (C) 2017 EJ Kreinar
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "nnet_helpers.h"
#include "ex_iqconv.h"

int main(int argc, char **argv)
{
  // Modulation recognition examples

  hls::stream<input_t> data_i, data_q;
  for (int ii=0; ii < N_IN; ii++) {
    data_i << 0.01*ii;
    data_q << 0.01*ii+0.005;
  }

  hls::stream<result_t> res_strm;
  unsigned short size_in, size_out;

  ex_iqconv(data_i, data_q, res_strm, size_in, size_out);

  std::cout << "Found network size: " << size_in << "x" << size_out << std::endl;

  // Print result vector
  int err_cnt = 0;
  float err, curr_data;
  for (int ii = 0; ii < N_LAYER_OUT; ii++) {
    for (int jj = 0; jj < 1; jj++) {
      curr_data = float(res_strm.read());
      // err = curr_data-answer[ii];
      // std::cout << "   Received: " << curr_data << std::endl;
      std::cout << "Row/Chan: " << ii << "/" << jj << ": " << curr_data  << std::endl; //<< ", Ref: " << refval << ", Err: " << err << std::endl;
      // std::cout << " Expected: " << answer[ii] << "   Received: " << curr_data << "  ErrVal: " << err << std::endl;
      // if (abs(err) > 0.5) err_cnt++;
    }
  }
  std::cout<< "Done read" << std::endl;
  // std::cout << res_strm.read() << std::endl;
  // std::cout << res_strm.read() << std::endl;
  // std::cout << res_strm.read() << std::endl;
  // std::cout << res_strm.read() << std::endl;
  // std::cout<< err_cnt << std::endl;
  return err_cnt;
}
