-- vim:ft=vhdl	ts=4 sw=4:
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity digital_key is
   port(
			rstn		: in	std_logic;
			clk			: in	std_logic;

   		sw_up		: in	std_logic;
   		sw_down		: in	std_logic;
			sw_sel		: in	std_logic;

   		fnd_cnt		: out	std_logic_vector( 6 downto 0);
   		fnd_key_0	: out	std_logic_vector( 6 downto 0);
   		fnd_key_1	: out	std_logic_vector( 6 downto 0);
   		fnd_key_2	: out	std_logic_vector( 6 downto 0);
   		fnd_key_3	: out	std_logic_vector( 6 downto 0);

   		fnd_door	: out	std_logic_vector( 6 downto 0);	
				
			led		:	out	std_logic_vector( 3 downto 0)			
   );
end digital_key;

architecture u_key of digital_key is

	constant SECRET_NUM		: std_logic_vector(15 downto 0) := x"1234";

	function fnd_dec(x : in std_logic_vector( 3 downto 0)) return std_logic_vector is
																				--값에 맞는 리턴값 	
		variable temp	: std_logic_vector( 6 downto 0);
	begin
		case x is
			when "0000" => temp := "1000000";	-- 0
			when "0001" => temp := "1111001";	-- 1
			when "0010" => temp := "0100100";	-- 2
			when "0011" => temp := "0110000";	-- 3
			when "0100" => temp := "0011001";	-- 4
			when "0101" => temp := "0010010";	-- 5
			when "0110" => temp := "0000010";	-- 6
			when "0111" => temp := "1011000";	-- 7
			when "1000" => temp := "0000000";	-- 8
			when "1001" => temp := "0010000";	-- 9

			when "1110" => temp := "0100011";	-- 'o'pen
			when "1111" => temp := "0100111";	-- 'c'lose
			when others => null;
		end case;

		return temp;

	end function;

	type state_type is (S_IDLE, S_SUCC0, S_SUCC1, S_SUCC2, S_OPEN, 
	                            S_FAIL0, S_FAIL1, S_FAIL2, S_CLOSE);
	signal state		: state_type;

	signal	sw_up_n		: std_logic;
	signal	sw_down_n	: std_logic;
	signal	sw_sel_n		: std_logic;

	signal	sw_en			: std_logic;
	signal	sw_en_d		: std_logic;

	signal	sw_re			: std_logic;

	signal	up				: std_logic;
	signal	down			: std_logic;
	signal	sel			: std_logic;
	signal	updown_cnt	: std_logic_vector( 3 downto 0);
	
	signal led_buf			:	std_logic_vector(3 downto 0);
	signal right_sig 		: std_logic;
	signal left_sig 		: std_logic;
	
	
	signal cnt				:	std_logic_vector(24 downto 0);
	signal clk_inv			:	std_logic;
	signal clk_temp 		: std_logic;
	
begin

	--------------------------------------------------------------------------------
	-- invert input signal
	--------------------------------------------------------------------------------
	sw_up_n		<= not sw_up;
	sw_down_n	<= not sw_down;
	sw_sel_n	<= not sw_sel;
	
	-- DE2 board  ==> pull_up ==> active low ()

	sw_en <= sw_up_n or sw_down_n or sw_sel_n;		
	
	--------------------------------------------------------------------------------
	-- generate clock for LED(Right_shift, Left_shift)
	--------------------------------------------------------------------------------
	process(rstn,clk)
	begin
		if(rstn = '0') then
			cnt <= (others=> '0');
		elsif rising_edge (clk) then
			if(cnt = 50000000) then
				cnt <= (others => '0');
			else
				cnt <= cnt + 1;
			end if;
		end if;
	end process;
		
	clk_inv <= '1' when (cnt = 24999999) else '0';
		
	process (rstn,clk)
		begin
			if(rstn = '0') then
				clk_temp <= '0';
			elsif rising_edge (clk) then
				if(clk_inv = '1') then
					clk_temp <= not clk_temp;
			end if;
		end if;
	end process;
	
	
	
	
	
	--------------------------------------------------------------------------------
	-- switch key enable
	--------------------------------------------------------------------------------
	process (rstn, clk)
	begin
		if (rstn = '0') then
			sw_en_d <= '0';
		elsif rising_edge (clk) then
			sw_en_d <= sw_en;
		end if;
	end process;

	sw_re <= '1' when ((sw_en = '1') and (sw_en_d = '0')) else '0';

	--------------------------------------------------------------------------------
	-- up/donw/sel switch check
	--------------------------------------------------------------------------------
	process (rstn, clk)		
	begin
		if (rstn = '0') then
			up   <= '0';
			down <= '0';
			sel  <= '0';
		elsif rising_edge (clk) then
			if (sw_re = '1') then
				if (sw_up_n = '1') then
					up   <= '1';
					down <= '0';
					sel  <= '0';
				elsif (sw_down_n = '1') then
					up   <= '0';
					down <= '1';
					sel  <= '0';
				elsif (sw_sel_n = '1') then
					up   <= '0';
					down <= '0';
					sel  <= '1';
				else
					up   <= '0';
					down <= '0';
					sel  <= '0';
				end if;
			else
				up   <= '0';
				down <= '0';
				sel  <= '0';
			end if;
		end if;
	end process;

	--------------------------------------------------------------------------------
	-- up/down counter
	--------------------------------------------------------------------------------
	process (rstn, clk)
	begin
		if (rstn = '0') then
			updown_cnt <= "0000";
		elsif rising_edge (clk) then
			if (up = '1') then
				if (updown_cnt = "1001") then
					updown_cnt <= "0000";
				else
					updown_cnt <= updown_cnt + 1;
				end if;
			elsif (down = '1') then
				if (updown_cnt = "0000") then
					updown_cnt <= "1001";
				else
					updown_cnt <= updown_cnt - 1;
				end if;
			end if;
		end if;
	end process;

	fnd_cnt <= fnd_dec(updown_cnt);

	--------------------------------------------------------------------------------
	-- state machine for password
	--------------------------------------------------------------------------------
	process (rstn, clk)
	begin
		if (rstn = '0') then
			state <= S_IDLE;

   			fnd_key_0 <= fnd_dec("0000");
   			fnd_key_1 <= fnd_dec("0000");
   			fnd_key_2 <= fnd_dec("0000");
   			fnd_key_3 <= fnd_dec("0000");
   			fnd_door  <= fnd_dec("1111");
		elsif rising_edge (clk) then
			if (sel = '1') then
				case state is
					when S_IDLE  => 
						fnd_key_0 <= fnd_dec(updown_cnt);
						
							led <= "0000";
						
						if (updown_cnt = SECRET_NUM(15 downto 12)) then
							state <= S_SUCC0;
						else
							state <= S_FAIL0;
						end if;

					when S_SUCC0 =>
						fnd_key_1 <= fnd_dec(updown_cnt);

						if (updown_cnt = SECRET_NUM(11 downto  8)) then
							state <= S_SUCC1;
						else
							state <= S_FAIL1;
						end if;
						
					when S_SUCC1 =>
						fnd_key_2 <= fnd_dec(updown_cnt);

						if (updown_cnt = SECRET_NUM( 7 downto  4)) then
							state <= S_SUCC2;
						else
							state <= S_FAIL2;
						end if;

					when S_SUCC2 =>
						fnd_key_3 <= fnd_dec(updown_cnt);

						if (updown_cnt = SECRET_NUM( 3 downto  0)) then
							state <= S_OPEN;
							fnd_door  <= fnd_dec("1110");		-- open "o"		----------------------------------------------													
						else
							state <= S_CLOSE;
   							fnd_door  <= fnd_dec("1111");		-- close "c"-----------------------------------------------
								led <= "0100";
						end if;

					when S_FAIL0 =>
						state <= S_FAIL1;
						fnd_key_1 <= fnd_dec(updown_cnt);

					when S_FAIL1 =>
						state <= S_FAIL2;
						fnd_key_2 <= fnd_dec(updown_cnt);

					when S_FAIL2 =>
						state <= S_CLOSE;
						fnd_key_3 <= fnd_dec(updown_cnt);
						fnd_door  <= fnd_dec("1111");		-- close "c"
						
						led <= "0100";
						
					when S_OPEN  =>
						state <= S_IDLE;
						
  						fnd_key_0 <= fnd_dec("0000");
  						fnd_key_1 <= fnd_dec("0000");
  						fnd_key_2 <= fnd_dec("0000");
  						fnd_key_3 <= fnd_dec("0000");
						fnd_door  <= fnd_dec("1111");		-- close "c"
						
					when S_CLOSE =>
						state <= S_IDLE;

   						fnd_key_0 <= fnd_dec("0000");
   						fnd_key_1 <= fnd_dec("0000");
   						fnd_key_2 <= fnd_dec("0000");
   						fnd_key_3 <= fnd_dec("0000");
						fnd_door  <= fnd_dec("1111");		-- close "c"

					when others => state <= S_IDLE;
				end case;
			end if;
		end if;
	end process;


right_sig <= '1' when (state = s_oPEN) else '0';
left_sig <= '1' when (state = s_cLOSE) else '0';


process(rstn, clk_temp)
begin
	if(rstn = '0') then
		led_buf <= "1000";
	elsif rising_edge(clk_temp) then
		if(right_sig = '1') then
			led_buf <= led_buf(0) & led_buf(3 downto 1);
		elsif(left_sig = '1') then
			led_buf <= led_buf(2 downto 0) & led_buf(3);
		end if;
	end if;
	led <= led_buf;
end process;
	
end u_key;
