import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';

import { FilterAdministradoresPipe } from '../pipes/filter-administradores';
import { AuthService } from '../services/auth.service';

import { AdministradoresService, User } from '../services/administradores.service';

@Component({
  selector: 'app-utentes-lista',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    RouterModule,
    FilterAdministradoresPipe
  ],
  templateUrl: './administradores-lista.component.html',
  styleUrls: ['./administradores-lista.component.css']
})
export class AdministradoresListaComponent implements OnInit {
  users: User[] = [];
  showInsertModal: boolean = false;
  showModal: boolean = false;
  showViewModal = false;
  userVisualizar: any = {};
  novoUser: User = this.criarUserVazio();
  userSelecionado: User = this.criarUserVazio();

  filtroNome: string = '';
  filtroSpeciality: string = '';
  submitted: boolean = false;
  usernameExistente: boolean = false;
  showMenu: boolean = false;

  user: User | null = null;




  constructor(
    private authService: AuthService,
    private administradoresService: AdministradoresService
  ) { }

  ngOnInit(): void {
    this.administradoresService.getUser().subscribe(data => {
      this.users = data;
    });
    this.user = this.authService.getUser();


  }
    toggleMenu() {
    console.log('toggleMenu clicado');
    this.showMenu = !this.showMenu;
  }
    logout() {
    this.authService.logout();
  }
  abrirInsertModal(): void {
    this.novoUser = this.criarUserVazio();
    this.showInsertModal = true;
  }
  abrirEditModal(user: User): void {
    this.userSelecionado = { ...user };
    this.showModal = true;
  }
  abrirViewModal(user: any) {
    this.userVisualizar = { ...user };
    this.showViewModal = true;
  }

  fecharViewModal() {
    this.showViewModal = false;
  }

  fecharInsertModal(): void {
    this.showInsertModal = false;
  }
  fecharEditModal(): void {
    this.showModal = false;
  }
  private criarUserVazio(): User {
    return {
       _id: '',
      nome: '',
      contacto: '',
      genero: '',
      nascimento: '',
      password: '',
      email: '',
      username: '',
      isAdmin: false

    };
  }

  guardarNovoUser(): void {
    this.submitted = true;

    const camposPreenchidos =
      this.novoUser.nome.trim() !== '' &&
      this.novoUser.contacto.trim() !== '' &&
      this.novoUser.genero.trim() !== '' &&
      this.novoUser.nascimento.trim() !== '' &&
      this.novoUser.email.trim() !== '' &&
      this.novoUser.username.trim() !== '' &&
      this.novoUser.password.trim() !== ''; const emailValido = this.isEmailValido();
    const passwordValida = this.isPasswordValida();
    const contactoValido = this.isContactoValido();
    const nascimentoValido = this.isDataNascimentoValida();

    console.log('camposPreenchidos:', camposPreenchidos);
    console.log('emailValido:', emailValido);
    console.log('passwordValida:', passwordValida);
    console.log('contactoValido:', contactoValido);
    console.log('nascimentoValido:', nascimentoValido);

    if (!camposPreenchidos || !emailValido || !passwordValida || !contactoValido || !nascimentoValido) {
      console.warn('Validação falhou. Não vai continuar.');
      return;
    }

    this.administradoresService.getUsers().subscribe(existing => {
      this.usernameExistente = existing.some(m => m.username === this.novoUser.username);
      console.log('Username já existe?', this.usernameExistente);

      if (this.usernameExistente) {
        console.warn('Username já existe. Parar.');
        return;
      }

      const payload = {
        nome: this.novoUser.nome,
        contacto: this.novoUser.contacto,
        genero: this.novoUser.genero,
        dataNascimento: new Date(this.novoUser.nascimento).toISOString(),
        username: this.novoUser.username,
        email: this.novoUser.email,
        password: this.novoUser.password,
      };


      this.administradoresService.registarUser(payload).subscribe({
        next: () => {
          console.log('User registado com sucesso!');
          this.fecharInsertModal();
          this.submitted = false;
          this.administradoresService.getUser().subscribe(data => {
            this.users = data;
          });
        },
        error: (err) => {
          console.error('Erro ao inserir administrador:');
        }
      });
    });
  }


  guardarEdicao(): void {
    this.submitted = true;

    const camposPreenchidos =
      this.userSelecionado.nome.trim() !== '' &&
      this.userSelecionado.contacto.trim() !== '' &&
      this.userSelecionado.genero.trim() !== '' &&
      this.userSelecionado.nascimento.trim() !== '';

    const contactoValido = /^\d{9}$/.test(this.userSelecionado.contacto);
    const nascimentoValido = new Date(this.userSelecionado.nascimento) < new Date();

    console.log('camposPreenchidos:', camposPreenchidos);
    console.log('contactoValido:', contactoValido);
    console.log('nascimentoValido:', nascimentoValido);

    if (!camposPreenchidos || !contactoValido || !nascimentoValido) {
      console.warn('Validação falhou. Não vai continuar.');
      return;
    }

    this.administradoresService.atualizarUser(this.userSelecionado).subscribe({
      next: () => {
        const index = this.users.findIndex(u => u. _id === this.userSelecionado. _id);
        if (index !== -1) {
          this.users[index] = { ...this.userSelecionado };
        }
        this.fecharEditModal();
        this.administradoresService.getUser().subscribe(data => {
          this.users = data;
        });
        alert('Administrador atualizado com sucesso!');
      },
      error: (err) => {
        console.error('Erro ao atualizar administrador:');
        alert('Ocorreu um erro ao atualizar o administrador.');
      }
    });
  }


  delete(user: User): void {
    if (confirm(`Tem certeza que deseja eliminar o administrador ${user.nome}?`)) {
      this.administradoresService.deleteUser(user.username).subscribe({
        next: () => {
          this.users = this.users.filter(m => m.username !== user.username);
          this.fecharEditModal();
          alert('Administrador eliminado com sucesso!');
        },
        error: (err) => {
          console.error('Erro ao eliminar administrador:');
          alert('Erro ao eliminar medico.');
        }
      });

    }

  }
  isContactoValido(): boolean {
    return /^\d{9}$/.test(this.novoUser.contacto);
  }

  isDataNascimentoValida(): boolean {
    const hoje = new Date();
    const nascimento = new Date(this.novoUser.nascimento);
    return nascimento < hoje;
  }
  verificarUsername(): void {
    if (!this.novoUser.username) {
      this.usernameExistente = false;
      return;
    }

    this.administradoresService.getUsers().subscribe(users => {
      this.usernameExistente = users.some(u => u.username === this.novoUser.username);
    });
  }
  isEmailValido(): boolean {
    const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return regex.test(this.novoUser.email);
  }

  isPasswordValida(): boolean {
    return typeof this.novoUser.password === 'string' && this.novoUser.password.length >= 6;
  }

  isContactoValidoEdicao(): boolean {
    return /^\d{9}$/.test(this.userSelecionado.contacto);
  }

  isDataNascimentoValidaEdicao(): boolean {
    const hoje = new Date();
    const nascimento = new Date(this.userSelecionado.nascimento);
    return nascimento < hoje;
  }


}
