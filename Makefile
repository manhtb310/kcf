# Makefile to build all the available variants

BUILDS = opencvfft-st opencvfft-async opencvfft-openmp fftw fftw-async fftw-openmp fftw-big fftw-big-openmp cufftw cufftw-big cufftw-big-openmp cufft cufft-openmp cufft-big cufft-big-openmp
TESTSEQ = bag ball1 car1 book
TESTFLAGS = default fit128

all: $(BUILDS)

ninja: build.ninja
	ninja

$(BUILDS): build.ninja
	ninja build-$@/build.ninja
	ninja -C build-$@

clean: build.ninja
	ninja $@

CMAKE_OPTS += -G Ninja

## Useful setting - uncomment and modify as needed
# CMAKE_OPTS += -DOpenCV_DIR=~/opt/opencv-2.4/share/OpenCV
# CMAKE_OPTS += -DCUDA_VERBOSE_BUILD=ON -DCUDA_NVCC_FLAGS="--verbose;--save-temps"
# export CC=gcc-5
# export CXX=g++-5
# export CUDA_BIN_PATH=/usr/local/cuda-9.0
# export CUDA_ARCH_LIST=6.2

CMAKE_OTPS_opencvfft-st      = -DFFT=OpenCV
CMAKE_OTPS_opencvfft-async   = -DFFT=OpenCV -DASYNC=ON
CMAKE_OTPS_opencvfft-openmp  = -DFFT=OpenCV -DOPENMP=ON
CMAKE_OTPS_fftw              = -DFFT=fftw
CMAKE_OTPS_fftw-openmp       = -DFFT=fftw -DOPENMP=ON
CMAKE_OTPS_fftw-async        = -DFFT=fftw -DASYNC=ON
CMAKE_OTPS_fftw-big          = -DFFT=fftw -DBIG_BATCH=ON
CMAKE_OTPS_fftw-big-openmp   = -DFFT=fftw -DBIG_BATCH=ON -DOPENMP=ON
CMAKE_OTPS_cufftw            = -DFFT=cuFFTW $(if $(CUDA_ARCH_LIST),-DCUDA_ARCH_LIST='$(CUDA_ARCH_LIST)')
CMAKE_OTPS_cufftw-big        = -DFFT=cuFFTW $(if $(CUDA_ARCH_LIST),-DCUDA_ARCH_LIST='$(CUDA_ARCH_LIST)') -DBIG_BATCH=ON
CMAKE_OTPS_cufftw-big-openmp = -DFFT=cuFFTW $(if $(CUDA_ARCH_LIST),-DCUDA_ARCH_LIST='$(CUDA_ARCH_LIST)') -DBIG_BATCH=ON -DOPENMP=ON
CMAKE_OTPS_cufft             = -DFFT=cuFFT  $(if $(CUDA_ARCH_LIST),-DCUDA_ARCH_LIST='$(CUDA_ARCH_LIST)')
CMAKE_OTPS_cufft-openmp	     = -DFFT=cuFFT  $(if $(CUDA_ARCH_LIST),-DCUDA_ARCH_LIST='$(CUDA_ARCH_LIST)') -DOPENMP=ON
CMAKE_OTPS_cufft-big         = -DFFT=cuFFT  $(if $(CUDA_ARCH_LIST),-DCUDA_ARCH_LIST='$(CUDA_ARCH_LIST)') -DBIG_BATCH=ON
CMAKE_OTPS_cufft-big-openmp  = -DFFT=cuFFT  $(if $(CUDA_ARCH_LIST),-DCUDA_ARCH_LIST='$(CUDA_ARCH_LIST)') -DBIG_BATCH=ON -DOPENMP=ON

##########################
### Tests
##########################

print-test-results = grep ^Average $(1)|sed -E -e "s|build-(.*)/kcf_vot-(.*).log:|\2;\1;|"|sort|column -t -s";"

test $(BUILDS:%=test-%) $(SEQ:%=test-%): build.ninja
	ninja $@

vot2016 $(TESTSEQ:%=vot2016/%): vot2016.zip
	unzip -d vot2016 -q $^
	for i in $$(ls -d vot2016/*/); do ( echo Creating $${i}images.txt; cd $$i; ls *.jpg > images.txt ); done

.INTERMEDIATE: vot2016.zip
.SECONDARY:    vot2016.zip
vot2016.zip:
	wget http://data.votchallenge.net/vot2016/vot2016.zip

###################
# Ninja generator #
###################

# Building all $(BUILDS) with make is slow, even when run with in
# parallel (make -j). The target below generates build.ninja file that
# compiles all variants in the same ways as this makefile, but faster.
# The down side is that the build needs about 10 GB of memory.

define nl


endef

define echo
echo $(1) '$(subst $(nl),\n,$(subst \,\\,$(2)))';
endef

# Ninja generator - to have faster parallel builds and tests
.PHONY: build.ninja build.ninja.new

build.ninja: build.ninja.new
	@cmp -s $@ $< || mv -v $< $@

build.ninja.new:
	@$(call echo,>$@,$(ninja-rule))
	@$(foreach build,$(BUILDS),\
		$(call echo,>>$@,$(call ninja-build,$(build),$(CMAKE_OTPS_$(build)))))
	@$(foreach build,$(BUILDS),$(foreach seq,$(TESTSEQ),$(foreach f,$(TESTFLAGS),\
		$(call echo,>>$@,$(call ninja-testcase,$(build),$(seq),$(f)))$(nl))))
	@$(call echo,>>$@,build test: PRINT_RESULTS $(foreach build,$(BUILDS),$(foreach seq,$(TESTSEQ),$(foreach f,$(TESTFLAGS),$(call ninja-test,$(build),$(seq),$(f))))))
	@$(foreach build,$(BUILDS),$(call echo,>>$@,build test-$(build): PRINT_RESULTS $(foreach seq,$(TESTSEQ),$(foreach f,$(TESTFLAGS),$(call ninja-test,$(build),$(seq),$(f))))))
	@$(foreach seq,$(TESTSEQ),$(call echo,>>$@,build test-$(seq): PRINT_RESULTS $(foreach build,$(BUILDS),$(foreach f,$(TESTFLAGS),$(call ninja-test,$(build),$(seq),$(f))))))
	@$(foreach seq,$(TESTSEQ),$(call echo,>>$@,build vot2016/$(seq): MAKE))


define ninja-rule
rule CMAKE
  command = cd $$$$(dirname $$out) && cmake $(CMAKE_OPTS) $$opts ..
rule NINJA
  # Absolute path in -C allows Emacs to properly jump to error message locations
  command = ninja -C `realpath $$$$(dirname $$out)` && touch $$out
  description = Ninja $$out
rule TEST_SEQ
  command = build-$$build/kcf_vot $$flags $$seq > $$out
rule PRINT_RESULTS
  description = Print results
  command = $(call print-test-results,$$in)
rule MAKE
  command = make $$out
rule CLEAN
#  command = /usr/bin/ninja -t clean -r NINJA
  description = Cleaning all built files...
  command = rm -rf $(BUILDS:%=build-%)
build clean: CLEAN
endef

define ninja-build
build build-$(1)/build.ninja: CMAKE
  opts = $(2)
build build-$(1)/kcf_vot: NINJA build-$(1)/build.ninja $(shell git ls-files)
default build-$(1)/kcf_vot
endef

ninja-test = build-$(1)/kcf_vot-$(2)-$(3).log

# Usage: ninja-testcase <build> <seq> <flags>
define ninja-testcase
build build-$(1)/kcf_vot-$(2)-$(3).log: TEST_SEQ build-$(1)/kcf_vot $(filter-out %/output.txt,$(wildcard vot2016/$(2)/*)) || vot2016/$(2)
  build = $(1)
  seq = vot2016/$(2)
  flags = $(if $(3:fit128=),,--fit=128)
endef
