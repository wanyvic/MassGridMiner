#ifndef _W_ECHO_H_
#define _W_ECHO_H_

#ifdef __cplusplus
extern "C" {
#endif
	void echo_scanHash_pre(unsigned char* input, unsigned  char* output, const unsigned int nonce);
	void echo_scanHash_post(unsigned char* input, unsigned char* output);
#ifdef __cplusplus
}
#endif
#endif