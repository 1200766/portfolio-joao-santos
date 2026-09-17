import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { HttpClientModule } from '@angular/common/http';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule, HttpClientModule],
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.css']
})

export class LoginComponent {
  identificador: string = '';
  password: string = '';
  errorMessage: string = '';

  constructor(private authService: AuthService, private router: Router) { }
  login(): void {
    this.errorMessage = ''; // Limpa mensagem anterior

    if (!this.identificador || !this.password) {
      this.errorMessage = 'Todos os campos devem ser preenchidos.';
      return;
    }

    this.authService.login(this.identificador, this.password).subscribe({
      next: (response) => {
        if (response.success && response.token && response.role) {
          this.authService.saveToken(response.token);

          if (response['user']) {
            this.authService.setUser(response['user']); // guarda o user
          }

          switch (response.role) {
            case 'admin':
              this.router.navigate(['/utentes-lista']);
              break;
            case 'medico':
              this.router.navigate(['/calendario']);
              break;
            case 'utente':
              this.router.navigate(['/loco']);
              break;
            default:
              this.errorMessage = 'Função de utilizador desconhecida.';
          }
        } else {
          this.errorMessage = response.message || 'Credenciais inválidas.';
        }
      },
      error: (err) => {
        console.error('Erro no login:');
        this.errorMessage = 'Credenciais inválidas.';
      }
    });
  }

}
